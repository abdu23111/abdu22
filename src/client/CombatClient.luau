-- Client half of combat, in 3D: nail swings with instant feedback (a gentle auto-aim toward
-- nearby foes, blade arcs, impact frames with hit-stop, pogo and recoil), lock-on, the
-- charged Cleaving Arc, the Lumen Bolt, focusing Soul to heal, and small flourishes for
-- dashing, dodging, double jumps, running and landing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Hitbox = require(Shared.Hitbox)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)
local Movement = require(script.Parent.Movement)
local CameraController = require(script.Parent.CameraController)
local Characters = require(script.Parent.Characters)
local Sfx = require(script.Parent.Sfx)
local Fx = require(script.Parent.Fx)

local player = Players.LocalPlayer

local CombatClient = {}

local lastAttack = -math.huge
local lastBolt = -math.huge
local focusing = false
local chargeStart: number? = nil
local chargeReady = false
local chargeFx: ParticleEmitter? = nil
local reticle: BillboardGui? = nil

local NAIL_COLOR = Color3.fromRGB(240, 244, 255)
local CLEAVE_COLOR = Color3.fromRGB(255, 215, 255)
local SOUL_COLOR = Color3.fromRGB(225, 235, 255)
local AIM_RANGE = 10
local LOCK_RANGE = 48

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function refreshTargets()
	local list = {}
	for _, name in { "Enemies", "Echoes" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	local world = workspace:FindFirstChild("World")
	if world then
		for _, zone in world:GetChildren() do
			for _, name in { "Breakables", "Switches" } do
				local b = zone:FindFirstChild(name)
				if b then
					table.insert(list, b)
				end
			end
		end
	end
	overlap.FilterDescendantsInstances = list
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

-- Living foes' hitboxes.
local function foes(): { BasePart }
	local list = {}
	local folder = workspace:FindFirstChild("Enemies")
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart and not model:GetAttribute("Dead") then
				table.insert(list, model.PrimaryPart)
			end
		end
	end
	return list
end

local function alive(target: BasePart?): boolean
	if not target or not target.Parent then
		return false
	end
	local model = target.Parent
	return model.Parent ~= nil and not model:GetAttribute("Dead")
end

-- ===== Lock-on =====

local function setLock(target: BasePart?)
	State.lockTarget = target
	if reticle then
		reticle.Adornee = target :: any
		reticle.Enabled = target ~= nil
	end
end

local function makeReticle()
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockReticle"
	gui.Size = UDim2.fromOffset(46, 46)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.LightInfluence = 0
	for i = 0, 3 do
		-- Four small corner ticks that slowly turn.
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Size = UDim2.fromOffset(10, 3)
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = Color3.fromRGB(235, 235, 250)
		tick.Name = "Tick" .. i
		tick.Parent = gui
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	reticle = gui
end

local function toggleLock()
	if Config.SIDE_VIEW then
		-- Everything is on one plane in side view; lock-on isn't needed.
		return
	end
	if State.lockTarget then
		setLock(nil)
		return
	end
	local root = State.root
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local camLook = flat(camera.CFrame.LookVector) or Vector3.zAxis
	local best, bestScore = nil, math.huge
	for _, part in foes() do
		local to = part.Position - root.Position
		local d = to.Magnitude
		local dir = flat(to)
		if d < LOCK_RANGE and dir then
			-- Prefer foes near the centre of the screen, then nearer ones.
			local score = d * 0.4 + (1 - camLook:Dot(dir)) * 40
			if score < bestScore then
				best, bestScore = part, score
			end
		end
	end
	if best then
		setLock(best)
		Sfx.play("ui", 1.3)
	end
end

-- ===== Nail =====

-- Where the swing should point: the lock-on target, else the nearest foe roughly ahead,
-- else where the character already faces.
local function aimDirection(root: BasePart): Vector3
	local look = State.facingVector
	if Config.SIDE_VIEW then
		-- Swing the way you're pressing, else the way you face.
		local m = Movement.moveWorld()
		return if m.X ~= 0 then Vector3.new(m.X, 0, 0) else Vector3.new(if look.X < 0 then -1 else 1, 0, 0)
	end
	if alive(State.lockTarget) then
		return flat((State.lockTarget :: BasePart).Position - root.Position) or look
	end
	local moveDir = flat(Movement.moveWorld())
	local ahead = moveDir or look
	local best, bestD = nil, AIM_RANGE
	for _, part in foes() do
		local to = part.Position - root.Position
		local dir = flat(to)
		local d = Vector3.new(to.X, 0, to.Z).Magnitude
		if dir and d < bestD and dir:Dot(ahead) > 0.25 and math.abs(to.Y) < 8 then
			best, bestD = dir, d
		end
	end
	return best or ahead
end

-- Up and down strikes follow the camera's pitch or where the foe is.
local function strikeDirection(root: BasePart): string
	if Config.SIDE_VIEW then
		if Input.lookUp() then
			return "up"
		elseif Input.lookDown() and not State.grounded then
			return "down"
		end
		return "side"
	end
	local camera = workspace.CurrentCamera
	local pitch = if camera then camera.CFrame.LookVector.Y else 0
	local target = if alive(State.lockTarget) then State.lockTarget else nil
	local dy = if target then target.Position.Y - root.Position.Y else 0
	local horizontal = if target then Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z).Magnitude else math.huge
	if not State.grounded and (pitch < -0.55 or (target and dy < -3 and horizontal < 5)) then
		return "down"
	end
	if pitch > 0.4 or (target and dy > 4 and horizontal < 6) then
		return "up"
	end
	return "side"
end

local CLIPS = { side = "attackSide", up = "attackUp", down = "attackDown", cleave = "cleave" }
local COMBO_CLIPS = { "attackSide", "attackSide2", "attackFinish" }

-- The combo: strike again within the window to chain into the next stage. Presses a moment
-- before the next swing is ready are buffered so chaining feels smooth, not fussy.
local COMBO_WINDOW = 0.55
local BUFFER = 0.2
local comboStage = 0
local comboUntil = 0
local nextAttackAt = 0
local queuedAt: number? = nil

-- Every attack's arc: where it sweeps (degrees, 0 = ahead, 90 = up), how big, and its look.
-- Radii and angles are chosen to lie over that attack's real hitbox (Shared/Hitbox).
type ArcSpec = { a0: number, a1: number, radius: number, lift: number, style: any }
local ARCS: { [string]: ArcSpec } = {
	side1 = { a0 = 75, a1 = -35, radius = 5.6, lift = 0.6, style = { color = Color3.fromRGB(240, 246, 255), glow = Color3.fromRGB(160, 200, 255), thickness = 0.5, sweep = 0.05, life = 0.15 } },
	side2 = { a0 = -80, a1 = 60, radius = 5.4, lift = 0.4, style = { color = Color3.fromRGB(215, 240, 255), glow = Color3.fromRGB(120, 230, 240), thickness = 0.45, sweep = 0.05, life = 0.15 } },
	finish = { a0 = 120, a1 = -50, radius = 7.2, lift = 0.8, style = { color = Color3.fromRGB(255, 244, 214), glow = Color3.fromRGB(255, 196, 110), thickness = 0.85, sweep = 0.07, life = 0.24, segments = 16 } },
	up = { a0 = 20, a1 = 160, radius = 4.6, lift = 1.2, style = { color = Color3.fromRGB(240, 246, 255), glow = Color3.fromRGB(170, 210, 255), thickness = 0.45, sweep = 0.05, life = 0.15 } },
	down = { a0 = 200, a1 = 340, radius = 4.6, lift = -1.2, style = { color = Color3.fromRGB(240, 246, 255), glow = Color3.fromRGB(170, 210, 255), thickness = 0.45, sweep = 0.05, life = 0.15 } },
	cleave = { a0 = 150, a1 = -55, radius = 9, lift = 0.6, style = { color = Color3.fromRGB(255, 225, 255), glow = Color3.fromRGB(230, 130, 255), thickness = 1.1, sweep = 0.08, life = 0.3, segments = 18 } },
}

local function slashArc(root: BasePart, key: string, facing: number, reach: number)
	local spec = ARCS[key]
	local center = root.Position + Vector3.new(0, spec.lift, 0)
	Fx.arc(center, facing, spec.radius * reach, spec.a0, spec.a1, spec.style, root)
end

local function localHits(cf: CFrame, direction: string, reach: number): { BasePart }
	refreshTargets()
	local box, size = Hitbox.nail(cf, direction, reach)
	return workspace:GetPartBoundsInBox(box, size, overlap)
end

local function swing(direction: string)
	local root = State.root
	if not root then
		return
	end
	local now = os.clock()
	local reach = if State.hasCharm("long_reach") then 1.35 else 1
	local look = aimDirection(root)
	-- Turn into the swing now so the animation, arc and hitbox agree.
	root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	State.facingVector = look
	local facing = if look.X < 0 then -1 else 1

	-- Which stage of the combo is this?
	local stage = 1
	if direction == "side" then
		stage = if now <= comboUntil and comboStage < 3 then comboStage + 1 else 1
		comboStage = stage
		comboUntil = now + COMBO_WINDOW
	else
		comboStage = 0
	end
	local finisher = direction == "side" and stage == 3
	local heavy = direction == "cleave" or finisher
	local hitReach = if finisher then reach * 1.25 else reach
	nextAttackAt = now + (if finisher then 0.5 elseif direction == "cleave" then 0.45 else Config.ATTACK_COOLDOWN)
	if finisher then
		comboStage = 0
		comboUntil = 0
		-- Commit to the finisher: a short step forward into the blow.
		Movement.shove(look * 16, 0.1)
	end

	Net.event("Attack"):FireServer(direction, look, stage)
	Characters.action(if direction == "side" then COMBO_CLIPS[stage] else CLIPS[direction])
	if heavy then
		Sfx.play("cleave", if finisher then 1.0 else 0.8)
	else
		Sfx.play("slash", ({ 1.0, 1.12, 1.0 })[stage] + (math.random() - 0.5) * 0.06)
	end
	local arcKey = if direction == "side" then (if stage == 2 then "side2" elseif stage == 3 then "finish" else "side1") else direction
	-- The arc is drawn as the blade passes its contact frame.
	task.delay(if finisher then 0.13 else 0.035, function()
		if root.Parent then
			slashArc(root, arcKey, facing, hitReach)
		end
	end)
	if direction == "cleave" then
		CameraController.shake(0.6)
	end

	local hitDirection = if direction == "cleave" then "cleave" else direction
	local function resolve()
		if not root.Parent then
			return
		end
		local hits = localHits(CFrame.lookAt(root.Position, root.Position + look), hitDirection, hitReach)
		if finisher then
			-- The chop meets the ground in front whether or not it hits anything.
			local ground = root.Position + look * 5 - Vector3.new(0, 2.9, 0)
			Fx.groundBurst(ground, Color3.fromRGB(255, 220, 160), 7)
			CameraController.shake(0.45)
		end
		if #hits == 0 then
			return
		end
		-- Impact frame: flash where the blade meets the nearest thing it struck, freeze for an
		-- instant, shake, and throw soul toward the player from anything living.
		local nearest, nearestD = hits[1], math.huge
		local soulFrom = nil
		for _, part in hits do
			local d = (part.Position - root.Position).Magnitude
			if d < nearestD then
				nearest, nearestD = part, d
			end
			local model = part:FindFirstAncestorOfClass("Model")
			if model and model.Parent and model.Parent.Name == "Enemies" then
				soulFrom = part.Position
			end
		end
		local contact = root.Position:Lerp(nearest.Position, 0.65) + Vector3.new(0, 0.5, 0)
		if Config.SIDE_VIEW then
			contact = Vector3.new(contact.X, contact.Y, 1.2)
		end
		local strikeDir = if direction == "up" then Vector3.yAxis elseif direction == "down" then -Vector3.yAxis else look
		local color = if direction == "cleave" then CLEAVE_COLOR elseif finisher then Color3.fromRGB(255, 220, 150) else nil
		Sfx.play(if heavy then "impact" else "hit", if stage == 2 then 1.1 else nil)
		Fx.impact(contact, strikeDir, color, heavy)
		Characters.hitStop(if heavy then 0.12 elseif stage == 2 then 0.065 else 0.055)
		CameraController.shake(if heavy then 0.9 elseif stage == 2 then 0.35 else 0.28)
		if soulFrom then
			Fx.wisps(soulFrom, root, if heavy then 4 else 2)
		end
		if direction == "down" then
			Movement.pogo()
			Fx.ring(contact - Vector3.new(0, 0.5, 0), NAIL_COLOR, 4, 0.3, 0.4)
		elseif direction == "side" then
			-- Recoil off whatever was struck.
			Movement.recoil(-1, if finisher then 20 else 14, if finisher then 0.1 else 0.07)
		end
	end
	-- Heavy blows land on their contact frame; quick ones resolve at once.
	if finisher then
		task.delay(0.13, resolve)
	else
		resolve()
	end
end

local function attack()
	local root = State.root
	if not root or State.frozen() or focusing then
		return
	end
	local now = os.clock()
	if now < nextAttackAt then
		-- Pressed a little early: remember it and swing the moment it's allowed.
		if nextAttackAt - now <= BUFFER then
			queuedAt = now
		end
		return
	end
	queuedAt = nil
	lastAttack = now
	swing(strikeDirection(root))

	-- Keep holding to charge the Cleaving Arc.
	if State.hasAbility("HasCleave") then
		chargeStart = now
		chargeReady = false
	end
end
CombatClient.attack = attack

local function stopCharge()
	chargeStart = nil
	chargeReady = false
	State.charging = false
	if chargeFx then
		chargeFx.Enabled = false
		chargeFx.Rate = 30
	end
end

local function releaseAttack()
	local ready = chargeReady
	stopCharge()
	if ready and State.root and not State.frozen() then
		lastAttack = os.clock()
		swing("cleave")
	end
end

-- ===== Lumen Bolt =====

local SOUL = Color3.fromRGB(225, 235, 255)

-- Up + spell: a scream of soul that bursts above you.
local function shriek(root: BasePart)
	Net.event("Spell"):FireServer("shriek")
	Characters.action("shriek")
	Sfx.play("roar", 1.6)
	CameraController.shake(0.6)
	local at = root.Position + Vector3.new(0, 3, 0)
	for i, r in { 4, 6.5, 9 } do
		task.delay(i * 0.05, function()
			Fx.arc(at, 1, r, 10, 170, { color = SOUL, glow = Color3.fromRGB(150, 180, 255), thickness = 0.55, sweep = 0.05, life = 0.3, segments = 14 }, root)
		end)
	end
	Fx.glitter(at + Vector3.new(0, 5, 0), SOUL, 30, 6)
	Fx.light(at + Vector3.new(0, 5, 0), SOUL, 30, 3, 0.4)
	Fx.sparks(at + Vector3.new(0, 2, 0), SOUL, 10, 2.5, Vector3.yAxis)
end

-- Down + spell in the air: plunge, then explode where you land.
local function dive(root: BasePart)
	Characters.action("jumpStart")
	Sfx.play("dash", 0.7)
	Movement.startDive()
	Fx.ring(root.Position, SOUL, 4, 0.25, 0.4)
end

local function bolt()
	local root = State.root
	if not root or State.frozen() or focusing then
		return
	end
	-- Direction picks the spell: up = scream, down in the air = dive, otherwise the Lumen Bolt.
	local soul = (player:GetAttribute("Soul") or 0) :: number
	if Input.lookUp() or (Input.lookDown() and not State.grounded) then
		if os.clock() - lastBolt < 0.45 or soul < Config.BOLT_COST or Movement.isDiving() then
			return
		end
		lastBolt = os.clock()
		if Input.lookUp() then
			shriek(root)
		else
			dive(root)
		end
		return
	end
	if not State.hasAbility("HasBolt") then
		return
	end
	local now = os.clock()
	if now - lastBolt < 0.4 or ((player:GetAttribute("Soul") or 0) :: number) < Config.BOLT_COST then
		return
	end
	lastBolt = now
	local look = State.facingVector
	local aim = look
	local target = State.lockTarget
	if alive(target) then
		local to = (target :: BasePart).Position - (root.Position + Vector3.new(0, 0.4, 0))
		aim = if to.Magnitude > 1e-3 then to.Unit else look
		look = flat(to) or look
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		State.facingVector = look
	end
	Net.event("Bolt"):FireServer(aim)
	Characters.action("bolt")
	Sfx.play("bolt", 0.9)
	Movement.recoil(-1, 18, 0.1)
	CameraController.shake(0.35)
	local muzzle = root.Position + look * 2.5 + Vector3.new(0, 0.4, 0)
	Fx.puff(muzzle, Color3.fromRGB(220, 240, 255), 2.4, 0.25)
	Fx.light(muzzle, Color3.fromRGB(220, 240, 255), 18, 3, 0.25)
	Fx.sparks(muzzle, SOUL_COLOR, 6, 1.2, look)
end

-- ===== Focus (heal) =====

local function focusFx(character: Model): (ParticleEmitter?, PointLight?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end
	local emitter = root:FindFirstChild("FocusGlow") :: ParticleEmitter?
	if not emitter then
		local e = Instance.new("ParticleEmitter")
		e.Name = "FocusGlow"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(230, 235, 255))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.5, 0)
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Rate = 40
		e.Speed = NumberRange.new(-4, -2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
		e.Enabled = false
		e.Parent = root
		emitter = e
	end
	local light = root:FindFirstChild("FocusLight") :: PointLight?
	if not light then
		local l = Instance.new("PointLight")
		l.Name = "FocusLight"
		l.Color = Color3.fromRGB(220, 230, 255)
		l.Range = 14
		l.Brightness = 0
		l.Parent = root
		light = l
	end
	return emitter, light
end

local function focus()
	if focusing then
		return
	end
	focusing = true
	local character = State.character
	local emitter, light
	if character then
		emitter, light = focusFx(character)
	end
	while Input.focusHeld do
		local soul = (player:GetAttribute("Soul") or 0) :: number
		local masks = (player:GetAttribute("Masks") or 0) :: number
		local maxMasks = (player:GetAttribute("MaxMasks") or 5) :: number
		if soul < Config.HEAL_COST or masks >= maxMasks or not State.grounded or State.frozen() then
			break
		end
		Movement.setRooted(true)
		if emitter and not emitter.Enabled then
			-- The gathering begins: a soft rising tone and light drawn inward.
			Sfx.play("charge", 0.6)
			if State.root then
				Fx.ring(State.root.Position - Vector3.new(0, 2.8, 0), Color3.fromRGB(220, 230, 255), 5, 0.5, 0.55)
			end
		end
		if emitter then
			emitter.Enabled = true
		end
		if light then
			light.Brightness = 2
		end
		local healTime = Config.HEAL_TIME * (if State.hasCharm("quiet_focus") then 0.6 else 1)
		local t = 0
		local cancelled = false
		while t < healTime do
			t += RunService.Heartbeat:Wait()
			if not Input.focusHeld or ((player:GetAttribute("Masks") or 0) :: number) < masks or State.frozen() then
				cancelled = true
				break
			end
		end
		if cancelled then
			break
		end
		Net.event("Heal"):FireServer()
		Sfx.play("heal", 1.3)
		if State.root then
			local at = State.root.Position
			Fx.glitter(at, Color3.fromRGB(230, 235, 255), 24, 2)
			Fx.ring(at - Vector3.new(0, 2.8, 0), Color3.fromRGB(220, 230, 255), 6, 0.5, 0.4)
			Fx.light(at, Color3.fromRGB(220, 230, 255), 20, 3, 0.4)
			Characters.flash(0.6)
			if State.hasCharm("kindled_spirit") then
				CameraController.shake(0.5)
				Fx.puff(at, Color3.fromRGB(255, 230, 170), 10, 0.5)
			end
		end
		task.wait(0.15)
	end
	Movement.setRooted(false)
	if emitter then
		emitter.Enabled = false
	end
	if light then
		light.Brightness = 0
	end
	focusing = false
end

-- ===== Init =====

function CombatClient.init()
	makeReticle()
	Input.on("attack", attack)
	Input.on("attackRelease", releaseAttack)
	Input.on("bolt", bolt)
	Input.on("focusStart", focus)
	Input.on("lock", toggleLock)

	local lastScrape = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		-- Wall slide: dust and sparks scraped off the stone where the claw drags.
		if State.action == "wall" and State.root and now - lastScrape > 0.07 then
			lastScrape = now
			local root = State.root
			local wallSide = -State.facingVector
			local contact = root.Position + wallSide * 1.4 + Vector3.new(0, 1.2, 0)
			Fx.puff(contact, Color3.fromRGB(170, 160, 150), 1, 0.35)
			if math.random() < 0.6 then
				Fx.sparks(contact, Color3.fromRGB(255, 225, 170), 2, 0.6, Vector3.new(0, 1, 0) - wallSide * 0.5)
			end
		end
		if queuedAt and now >= nextAttackAt then
			if now - queuedAt <= BUFFER + 0.1 then
				attack()
			end
			queuedAt = nil
		end
		-- Drop the lock when the target falls or wanders out of range.
		local target = State.lockTarget
		if target then
			local root = State.root
			if not alive(target) or not root or (target.Position - root.Position).Magnitude > LOCK_RANGE * 1.3 then
				setLock(nil)
			elseif reticle then
				local spin = now * 1.4
				for i = 0, 3 do
					local tick = reticle:FindFirstChild("Tick" .. i) :: Frame?
					if tick then
						local a = spin + i * math.pi / 2
						tick.Position = UDim2.new(0.5, math.cos(a) * 16, 0.5, math.sin(a) * 16)
						tick.Rotation = math.deg(a) + 90
					end
				end
			end
		end

		-- Charging the Cleaving Arc.
		if not chargeStart then
			return
		end
		if not Input.attackHeld or State.frozen() then
			stopCharge()
			return
		end
		local root = State.root
		if not root then
			return
		end
		local held = now - chargeStart
		if held > 0.2 then
			State.charging = true
			if not chargeFx or chargeFx.Parent ~= root then
				local e = Instance.new("ParticleEmitter")
				e.Name = "ChargeGlow"
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 255))
				e.LightEmission = 1
				e.Size = NumberSequence.new(0.4, 0)
				e.Lifetime = NumberRange.new(0.3, 0.5)
				e.Rate = 30
				e.Speed = NumberRange.new(-5, -3)
				e.Shape = Enum.ParticleEmitterShape.Sphere
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
				e.Parent = root
				chargeFx = e
			end
			(chargeFx :: ParticleEmitter).Enabled = true
		end
		if held >= Config.CLEAVE_CHARGE and not chargeReady then
			chargeReady = true
			Sfx.play("charge")
			Fx.glitter(root.Position, CLEAVE_COLOR, 18, 2)
			Fx.light(root.Position, CLEAVE_COLOR, 14, 2.5, 0.3)
			Characters.flash(0.5)
			if chargeFx then
				chargeFx.Rate = 90
			end
		end
	end)

	-- ===== Movement flourishes =====

	local DUST = Color3.fromRGB(165, 160, 165)

	Movement.onDash = function(dir: Vector3)
		local root = State.root
		if not root then
			return
		end
		for i = 0, 4 do
			task.delay(i * 0.035, function()
				Fx.afterimage(Characters.localRig(), Color3.fromRGB(40, 40, 64), 0.55 + i * 0.07, 0.22)
			end)
		end
		Fx.puff(root.Position - Vector3.new(0, 2.4, 0) - dir * 1.5, Color3.fromRGB(200, 200, 220), 2.6, 0.3)
	end

	Movement.onDodge = function(_dir: Vector3)
		Characters.action("dodge")
		for i = 0, 2 do
			task.delay(i * 0.045, function()
				Fx.afterimage(Characters.localRig(), Color3.fromRGB(210, 215, 245), 0.6 + i * 0.1, 0.25)
			end)
		end
	end

	Movement.onJump = function()
		Characters.action("jumpStart")
		local root = State.root
		if root then
			Fx.puff(root.Position - Vector3.new(0, 2.8, 0), DUST, 1.4, 0.3)
		end
	end

	Movement.onLand = function(position: Vector3, speed: number)
		if speed > 18 then
			-- Harder landings bend deeper (the clip plays faster the softer the landing).
			Characters.action("land", math.clamp(28 / speed, 0.7, 1.3))
			if speed > 70 then
				Fx.groundBurst(position, DUST, math.clamp(speed / 12, 3, 7))
				CameraController.shake(0.25)
			else
				Fx.ring(position, DUST, math.clamp(speed / 12, 2, 6), 0.4)
			end
		end
		Fx.puff(position, DUST, math.clamp(speed / 20, 1.5, 4.5), 0.45)
	end

	Movement.onDiveLand = function(position: Vector3)
		Net.event("Spell"):FireServer("dive")
		Characters.action("land", 0.8)
		Sfx.play("impact", 0.7)
		CameraController.shake(1)
		Characters.hitStop(0.08)
		Fx.groundBurst(position, SOUL, 12)
		Fx.crack(position, SOUL, 5)
		Fx.light(position + Vector3.new(0, 2, 0), SOUL, 36, 4, 0.5)
		for _, s in { -1, 1 } do
			Fx.arc(position + Vector3.new(0, 0.5, 0), s, 6, 0, 80, { color = SOUL, glow = Color3.fromRGB(150, 180, 255), thickness = 0.7, sweep = 0.06, life = 0.3 })
		end
		Fx.sparks(position + Vector3.new(0, 1, 0), SOUL, 14, 2.5, Vector3.yAxis)
	end

	-- The charge dash: crystals gather while held, then a streaking launch.
	local cdashGlow: ParticleEmitter? = nil
	local cdashTrail: RBXScriptConnection? = nil
	local CRYSTAL = Color3.fromRGB(255, 170, 230)
	Movement.onCdash = function(stage: string, info: Vector3?)
		local root = State.root
		if not root then
			return
		end
		if stage == "charge" then
			Sfx.play("charge", 0.8)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(CRYSTAL)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.45, 0)
			e.Lifetime = NumberRange.new(0.3, 0.5)
			e.Rate = 40
			e.Speed = NumberRange.new(-8, -5)
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
			e.Parent = root
			cdashGlow = e
		elseif stage == "ready" then
			Fx.glitter(root.Position, CRYSTAL, 20, 2)
			Fx.light(root.Position, CRYSTAL, 18, 3, 0.3)
			Characters.flash(0.5)
			if cdashGlow then
				cdashGlow.Rate = 110
			end
		elseif stage == "launch" then
			if cdashGlow then
				cdashGlow:Destroy()
				cdashGlow = nil
			end
			local dir = info or State.facingVector
			Sfx.play("cleave", 1.3)
			CameraController.shake(0.5)
			Fx.groundBurst(root.Position - Vector3.new(0, 2.6, 0), CRYSTAL, 6)
			Fx.sparks(root.Position, CRYSTAL, 12, 2.5, -dir)
			local last = 0
			cdashTrail = RunService.RenderStepped:Connect(function()
				local now = os.clock()
				if now - last > 0.035 and State.root then
					last = now
					Fx.afterimage(Characters.localRig(), CRYSTAL, 0.55, 0.22)
					Fx.sparks(State.root.Position - dir * 2, CRYSTAL, 2, 1.5, -dir)
				end
			end)
		else
			if cdashGlow then
				cdashGlow:Destroy()
				cdashGlow = nil
			end
			if cdashTrail then
				cdashTrail:Disconnect()
				cdashTrail = nil
			end
			if stage == "stop" and info then
				-- Slammed into a wall.
				Sfx.play("impact", 1)
				CameraController.shake(0.8)
				Fx.impact(info, -State.facingVector, CRYSTAL, true)
				Fx.debris(info, 6, nil, 4)
			end
		end
	end

	Movement.onWallJump = function(normal: Vector3)
		Characters.action("wallJump")
		local root = State.root
		if root then
			Fx.puff(root.Position - normal * 1.2, DUST, 1.6, 0.3)
			Fx.sparks(root.Position - normal * 1.4, Color3.fromRGB(220, 215, 200), 4, 0.8, normal)
		end
	end

	Movement.onStep = function(position: Vector3)
		Fx.puff(position, Color3.fromRGB(150, 146, 150), 0.9, 0.35)
	end

	Movement.onDoubleJump = function()
		local root = State.root
		if not root then
			return
		end
		Characters.action("flip")
		-- A pair of pale wings flare open behind the Wanderer and fade.
		local back = -State.facingVector
		local side = State.facingVector:Cross(Vector3.yAxis)
		for _, s in { -1, 1 } do
			local base = root.Position + back * 0.8 + side * s * 1.6 + Vector3.new(0, 0.6, 0)
			local wing = Fx.part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.3, 1.6, 3.6),
				CFrame = CFrame.lookAt(base, base + side * s) * CFrame.Angles(math.rad(s * 25), math.rad(90), 0),
				Color = Color3.fromRGB(245, 240, 225),
				Transparency = 0.2,
			})
			Fx.fade(wing, 0.35, { CFrame = wing.CFrame + Vector3.new(0, -1.5, 0) + side * s * 0.8 })
		end
		Fx.ring(root.Position - Vector3.new(0, 2.4, 0), Color3.fromRGB(245, 240, 225), 3, 0.3, 0.5)
	end

	-- The Silkline: a glowing thread from the Wanderer's raised hand to the ring.
	local thread: BasePart? = nil
	local threadConn: RBXScriptConnection? = nil
	Movement.onSwing = function(anchor: Vector3?)
		if thread then
			thread:Destroy()
			thread = nil
		end
		if threadConn then
			threadConn:Disconnect()
			threadConn = nil
		end
		local root = State.root
		if not anchor or not root then
			return
		end
		Fx.glitter(anchor, Color3.fromRGB(200, 240, 255), 14, 1.5)
		local t = Fx.part({ Size = Vector3.new(0.12, 0.12, 1), Color = Color3.fromRGB(215, 240, 255), Transparency = 0.1 })
		thread = t
		threadConn = RunService.RenderStepped:Connect(function()
			if not root.Parent or not t.Parent then
				return
			end
			local hand = root.Position + Vector3.new(0, 3.4, 0) + State.facingVector * 0.4
			local len = (anchor - hand).Magnitude
			t.Size = Vector3.new(0.12, 0.12, len)
			t.CFrame = CFrame.lookAt((hand + anchor) / 2, anchor)
		end)
	end

	Movement.onHurt = function()
		local root = State.root
		if root then
			Fx.impact(root.Position, -State.facingVector, Color3.fromRGB(20, 20, 30), true)
		end
		Sfx.play("impact", 0.8)
		Characters.hitStop(0.12)
		CameraController.shake(0.8)
	end
end

return CombatClient
