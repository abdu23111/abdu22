-- Boss arenas and the fight runtime. Each boss lives in Bosses/Defs as a data table plus a
-- scripted attack loop built from the helpers below (moves, leaps, telegraphs, floor
-- markers, beams, spires, ink tides, projectile volleys). The runtime adds:
--   * cinematic introductions (gates slam, camera pans to the boss, title card)
--   * phases at health thresholds, each opening with a stagger and roar
--   * readable warnings: bosses glow hot before striking, hazards are marked first
--   * a death sequence before rewards are handed out

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Grid = require(Shared.Grid)
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

type Hazard = { center: Vector3, size: Vector3, expires: number }

type Fight = {
	info: any,
	def: any,
	state: string, -- idle | intro | fighting | dying | cooldown
	participants: { [Player]: boolean },
	boss: any?,
	hazards: { Hazard },
	temp: { Instance },
	stateFolder: Folder,
}

local fights: { Fight } = {}

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

local function buildModel(def)
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
	if victory then
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
		phase = 1,
		pendingPhase = nil,
		staggering = false,
		cancelled = false,
		warning = false,
		hidden = false,
		walk = 0,
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

	local function rawWait(t: number)
		local elapsed = 0
		while elapsed < t do
			elapsed += RunService.Heartbeat:Wait()
			if b.cancelled then
				error(CANCEL)
			end
		end
	end

	local function stagger(phase: number)
		b.staggering = true
		b.warning = true
		local base = b.position
		local elapsed = 0
		while elapsed < 1.1 do
			elapsed += RunService.Heartbeat:Wait()
			if b.cancelled then
				error(CANCEL)
			end
			b.position = base + Vector3.new(math.sin(elapsed * 60) * 0.25, 0, 0)
		end
		b.position = base
		b.warning = false
		b.shake(1)
		Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 30)
		if def.onPhase then
			def.onPhase(b, phase)
		end
		b.staggering = false
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
	function b.wait(t: number)
		local elapsed = 0
		while elapsed < t do
			elapsed += b.step()
		end
	end
	function b.phase2(): boolean
		return b.phase >= 2
	end
	-- Later phases shorten the pauses between attacks.
	function b.pace(t: number): number
		return t * (1 - 0.18 * (b.phase - 1))
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
	-- Wind-up: the boss trembles and glows hot, so every attack can be read in advance.
	function b.telegraph(t: number)
		b.warning = true
		local base = b.position
		local ok, err = pcall(function()
			local elapsed = 0
			while elapsed < t do
				elapsed += b.step()
				b.position = base + Vector3.new(math.sin(elapsed * 70) * 0.18, 0, 0)
			end
		end)
		b.position = base
		b.warning = false
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
	-- A glowing floor strip (and faint column) marking where something is about to land.
	function b.marker(x: number, width: number, t: number)
		local strip = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = WARN,
			Transparency = 0.25,
			Size = Vector3.new(width, 0.35, Config.DEPTH + 0.6),
			Position = Vector3.new(x, b.floorY + 0.2, 0),
			Parent = workspace,
		})
		local column = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = WARN,
			Transparency = 0.88,
			Size = Vector3.new(width * 0.8, 16, 0.2),
			Position = Vector3.new(x, b.floorY + 8, 1),
			Parent = workspace,
		})
		temp(strip, t)
		temp(column, t)
		TweenService:Create(strip, TweenInfo.new(t / 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
	end
	-- A thin warning line across the arena at height y.
	function b.beamWarn(y: number, t: number)
		local line = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = WARN,
			Transparency = 0.45,
			Size = Vector3.new(fight.info.maxX - fight.info.minX, 0.25, 0.25),
			Position = Vector3.new((fight.info.minX + fight.info.maxX) / 2, y, 1),
			Parent = workspace,
		})
		temp(line, t)
	end
	function b.hazard(center: Vector3, size: Vector3, t: number)
		table.insert(fight.hazards, { center = center, size = size, expires = os.clock() + t })
	end
	-- A blazing horizontal beam across the arena.
	function b.beam(y: number, t: number)
		local width = fight.info.maxX - fight.info.minX
		local center = Vector3.new((fight.info.minX + fight.info.maxX) / 2, y, 0)
		local beam = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 220, 255),
			Transparency = 0.1,
			Size = Vector3.new(width, 2.2, 2.2),
			Position = center,
			Parent = workspace,
		})
		make("PointLight", { Range = 30, Brightness = 3, Color = Color3.fromRGB(255, 180, 255), Parent = beam })
		temp(beam, t)
		b.hazard(center, Vector3.new(width, 2.2, 4), t)
	end
	-- A crystal spire bursting from the floor.
	function b.spire(x: number, height: number, t: number)
		local spire = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(240, 160, 255),
			Transparency = 0.1,
			Size = Vector3.new(2.2, height, 2.2),
			CFrame = CFrame.new(x, b.floorY - height / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			Parent = workspace,
		})
		temp(spire, t + 0.3)
		TweenService:Create(spire, TweenInfo.new(0.12, Enum.EasingStyle.Back), { CFrame = CFrame.new(x, b.floorY + height / 2, 0) * CFrame.Angles(0, math.rad(45), 0) }):Play()
		task.delay(t, function()
			if spire.Parent then
				TweenService:Create(spire, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end)
		b.hazard(Vector3.new(x, b.floorY + height / 2, 0), Vector3.new(2.2, height, 4), t)
	end
	-- Flood the arena floor with ink up to `top` for a while (runs alongside other attacks).
	function b.inkTide(top: number, duration: number)
		local width = fight.info.maxX - fight.info.minX
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
			Size = Vector3.new(width, 0.2, Config.DEPTH + 1),
			Position = Vector3.new(cx, b.floorY, 0),
			Parent = workspace,
		})
		temp(ink)
		local height = top - b.floorY
		for _, player in Players:GetPlayers() do
			if fight.participants[player] then
				PlayerService.notify(player, "The ink is rising!", "Get off the floor.", "info")
			end
		end
		TweenService:Create(ink, TweenInfo.new(1, Enum.EasingStyle.Sine), { Size = Vector3.new(width, height, Config.DEPTH + 1), Position = Vector3.new(cx, b.floorY + height / 2, 0) }):Play()
		task.delay(1, function()
			if fight.boss == b and not b.cancelled then
				b.hazard(Vector3.new(cx, b.floorY + height / 2, 0), Vector3.new(width, height, 4), duration)
			end
		end)
		task.delay(1 + duration, function()
			if ink.Parent then
				TweenService:Create(ink, TweenInfo.new(0.8), { Size = Vector3.new(width, 0.2, Config.DEPTH + 1), Position = Vector3.new(cx, b.floorY, 0) }):Play()
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
		b.position = Vector3.new(b.position.X, b.floorY - 40, 0)
	end
	function b.appear(position: Vector3)
		b.position = position
		b.hidden = false
		b.dust(position)
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
	b.rawWait = rawWait
	return b
end

local function placeBoss(b, now: number, dt: number)
	local moved = math.abs(b.position.X - (b.lastX or b.position.X))
	b.lastX = b.position.X
	b.walk += moved * 0.9
	for _, entry in b.parts do
		local spec = entry.spec
		local o = spec.offset
		local rz = (spec.rz or 0) * b.dir
		local dy = 0
		if spec.flap then
			rz += math.sin(now * 9) * spec.flap
		end
		if spec.anim == "breath" then
			dy = math.sin(now * 2.2) * 0.15
		elseif spec.anim == "leg" then
			rz += math.sin(b.walk) * 0.35
		elseif spec.anim == "legB" then
			rz -= math.sin(b.walk) * 0.35
		elseif spec.anim == "cape" then
			rz += math.sin(now * 3) * 0.08 - math.clamp(moved / math.max(dt, 1e-3) / 200, 0, 0.3) * b.dir
		elseif spec.anim == "book" then
			dy = math.sin(now * 3) * 0.3
		end
		entry.part.CFrame = CFrame.new(b.position + Vector3.new(o.X * b.dir, o.Y + dy, o.Z)) * CFrame.Angles(0, 0, rz)
	end
	if b.warning then
		local pulse = 0.3 + 0.25 * math.sin(now * 30)
		for p, c in b.colors do
			p.Color = c:Lerp(WARN, pulse)
		end
		b.tinted = true
	elseif b.tinted then
		b.tinted = false
		for p, c in b.colors do
			p.Color = c
		end
	end
end

local function dyingSequence(fight: Fight, b)
	fight.state = "dying"
	b.cancelled = true
	fight.stateFolder:SetAttribute("Health", 0)
	table.clear(fight.hazards)
	Projectiles.clear()
	local def = fight.def
	for player in fight.participants do
		Net.event("Flash"):FireClient(player, 0.6)
		Net.event("CameraShake"):FireClient(player, 1.2)
	end
	task.spawn(function()
		for i = 1, 8 do
			Enemies.burst(b.position + Vector3.new(math.random(-3, 3), math.random(-2, 3), 0), Color3.fromRGB(255, 255, 255), 14)
			for p in b.colors do
				p.Color = if i % 2 == 0 then Color3.new(1, 1, 1) else b.colors[p]
			end
			task.wait(0.18)
		end
		Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 60)
		Enemies.burst(b.position, Color3.fromRGB(120, 220, 255), 40)
		for player in fight.participants do
			Net.event("AreaTitle"):FireClient(player, def.name, "has fallen", "victory")
			Net.event("CameraShake"):FireClient(player, 1)
		end
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
	fight.stateFolder:SetAttribute("Health", b.hp)
	fight.stateFolder:SetAttribute("MaxHealth", def.hp)
	fight.stateFolder:SetAttribute("Active", true)
	placeBoss(b, os.clock(), 1 / 60)
	b.model.Parent = workspace:FindFirstChild("Enemies")

	for _, p in players do
		fight.participants[p] = true
		Net.event("BossIntro"):FireClient(p, def.name, def.title, b.position, Config.BOSS_INTRO_TIME)
	end

	Damageable.register(b.model, {
		onHit = function(_player: Player, damage: number)
			if b.cancelled or b.hp <= 0 or fight.state ~= "fighting" or b.hidden then
				return false
			end
			b.hp -= damage
			fight.stateFolder:SetAttribute("Health", math.max(0, b.hp))
			if not b.warning then
				for p in b.colors do
					p.Color = Color3.new(1, 1, 1)
				end
				task.delay(0.07, function()
					if not b.warning then
						for p, c in b.colors do
							p.Color = c
						end
					end
				end)
			end
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
			b.rawWait(Config.BOSS_INTRO_TIME * 0.45)
			b.warning = true
			b.shake(0.9)
			Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 20)
			b.rawWait(Config.BOSS_INTRO_TIME * 0.35)
			b.warning = false
			b.rawWait(Config.BOSS_INTRO_TIME * 0.2)
			if fight.state == "intro" then
				fight.state = "fighting"
			end
			b.wait(0.4)
			def.run(b)
		end)
		if not ok and err ~= CANCEL then
			warn("[Vesperdeep] Boss error:", err)
		end
	end)
end

function Bosses.init(infos, playerService)
	PlayerService = playerService
	local stateRoot = make("Folder", { Name = "BossState", Parent = ReplicatedStorage })
	for _, info in infos do
		local bossInfo = info.boss
		if bossInfo then
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

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, fight in fights do
			if fight.state == "idle" then
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
				local anyone = false
				for player in fight.participants do
					local root = PlayerService.rootOf(player)
					local alive = player.Parent ~= nil and root ~= nil and (player:GetAttribute("Masks") or 0) > 0
					if alive and root and Grid.zoneAt(root.Position) == fight.info.zone then
						anyone = true
						if fight.state == "fighting" then
							local p = root.Position
							local d = p - b.position
							if not b.hidden and math.abs(d.X) < b.size.X / 2 + 0.9 and math.abs(d.Y) < b.size.Y / 2 + 2.4 then
								PlayerService.damage(player, 1, b.position)
							end
							for _, hz in fight.hazards do
								local h = p - hz.center
								if math.abs(h.X) < hz.size.X / 2 + 0.9 and math.abs(h.Y) < hz.size.Y / 2 + 2.4 then
									PlayerService.damage(player, 1, hz.center)
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
				else
					placeBoss(b, now, dt)
				end
			end
		end
	end)
end

return Bosses
