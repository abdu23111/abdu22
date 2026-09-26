-- Client half of combat: nail swings with instant feedback (slash arcs, pogo, recoil),
-- the charged Cleaving Arc, the Lumen Bolt, focusing Soul to heal, and small flourishes
-- for dashing, dodging, double jumps, running and landing.

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

-- A crescent of short glowing segments that follows the player for a moment.
local function slashArc(direction: string, reach: number, heavy: boolean?)
	local root = State.root
	if not root then
		return
	end
	local base = if direction == "up" then math.pi / 2 elseif direction == "down" then -math.pi / 2 elseif State.facing > 0 then 0 else math.pi
	local radius = (if heavy then 5.5 else 3.3) * reach
	local count = if heavy then 6 else 3
	local spread = if heavy then 15 else 19
	local color = if heavy then Color3.fromRGB(255, 225, 255) else Color3.fromRGB(245, 245, 255)
	local segments = {}
	for i = -count, count do
		local a = base + math.rad(i * spread)
		local thickness = (if heavy then 0.9 else 0.55) - math.abs(i) * (if heavy then 0.1 else 0.12)
		local p = Fx.part({
			Size = Vector3.new(math.max(0.15, thickness), if heavy then 2.6 else 1.9, 0.3),
			Color = color,
			Transparency = 0.1,
		})
		table.insert(segments, { part = p, angle = a })
		Fx.fade(p, if heavy then 0.26 else 0.16)
	end
	local center = if direction == "side" or heavy then Vector3.new(State.facing * 0.8, 0.3, 1.5) else Vector3.new(0, 0, 1.5)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not root.Parent or not segments[1].part.Parent then
			conn:Disconnect()
			return
		end
		local c = root.Position + center
		for _, s in segments do
			local offset = Vector3.new(math.cos(s.angle), math.sin(s.angle), 0) * radius
			if s.part.Parent then
				s.part.CFrame = CFrame.new(c + offset) * CFrame.Angles(0, 0, s.angle)
			end
		end
	end)
end

local function localHits(direction: string, reach: number): { BasePart }
	local root = State.root
	if not root then
		return {}
	end
	refreshTargets()
	local center, size = Hitbox.nail(root.Position, State.facing, direction, reach)
	return workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap), center
end

local function swing(direction: string)
	local reach = if State.hasCharm("long_reach") then 1.35 else 1
	Net.event("Attack"):FireServer(direction)
	local heavy = direction == "cleave"
	Sfx.play(if heavy then "cleave" else "slash", if heavy then 0.8 else nil)
	slashArc(if heavy then "side" else direction, reach, heavy)
	local hits, center = localHits(direction, reach)
	if heavy then
		CameraController.shake(0.7)
	end
	if #hits > 0 then
		Sfx.play("hit")
		Fx.sparks(center, if heavy then Color3.fromRGB(255, 210, 255) else nil, if heavy then 12 else 6)
		CameraController.shake(if heavy then 0.9 else 0.25)
		if direction == "down" then
			Movement.pogo()
		elseif direction == "side" then
			Movement.recoil(-State.facing, 14, 0.07)
		end
	end
end

local function attack()
	local root = State.root
	if not root or State.frozen() or focusing then
		return
	end
	local now = os.clock()
	if now - lastAttack < Config.ATTACK_COOLDOWN then
		return
	end
	lastAttack = now

	local direction = "side"
	if Input.lookUp() then
		direction = "up"
	elseif Input.lookDown() and not State.grounded then
		direction = "down"
	end
	swing(direction)

	-- Keep holding to charge the Cleaving Arc.
	if State.hasAbility("HasCleave") then
		chargeStart = now
		chargeReady = false
	end
end

local function releaseAttack()
	local ready = chargeReady
	chargeStart = nil
	chargeReady = false
	if chargeFx then
		chargeFx.Enabled = false
	end
	if ready and State.root and not State.frozen() then
		lastAttack = os.clock()
		swing("cleave")
	end
end

local function bolt()
	local root = State.root
	if not root or State.frozen() or focusing or not State.hasAbility("HasBolt") then
		return
	end
	local now = os.clock()
	if now - lastBolt < 0.4 or ((player:GetAttribute("Soul") or 0) :: number) < Config.BOLT_COST then
		return
	end
	lastBolt = now
	Net.event("Bolt"):FireServer()
	Sfx.play("bolt", 0.9)
	Movement.recoil(-State.facing, 18, 0.1)
	CameraController.shake(0.35)
	Fx.puff(root.Position + Vector3.new(State.facing * 2.5, 0.4, 0), Color3.fromRGB(220, 240, 255), 3, 0.25)
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
			Fx.sparks(State.root.Position, Color3.fromRGB(230, 235, 255), 8)
			if State.hasCharm("kindled_spirit") then
				CameraController.shake(0.5)
				Fx.puff(State.root.Position, Color3.fromRGB(255, 230, 170), 10, 0.5)
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

local function ghost(color: Color3)
	local root = State.root
	if not root then
		return
	end
	local p = Fx.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2, 4.4, 0.4),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Position = root.Position + Vector3.new(0, 0, -0.5),
	})
	Fx.fade(p, 0.25)
end

function CombatClient.init()
	Input.on("attack", attack)
	Input.on("attackRelease", releaseAttack)
	Input.on("bolt", bolt)
	Input.on("focusStart", focus)

	-- Charging glow for the Cleaving Arc.
	RunService.RenderStepped:Connect(function()
		if not chargeStart then
			return
		end
		if not Input.attackHeld or State.frozen() then
			chargeStart = nil
			chargeReady = false
			if chargeFx then
				chargeFx.Enabled = false
			end
			return
		end
		local root = State.root
		if not root then
			return
		end
		local held = os.clock() - chargeStart
		if held > 0.2 then
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
			Fx.sparks(root.Position, Color3.fromRGB(255, 210, 255), 10, 2)
			if chargeFx then
				chargeFx.Rate = 90
			end
		end
	end)

	Movement.onDash = function(dir: number)
		local root = State.root
		if not root then
			return
		end
		for i = 0, 3 do
			task.delay(i * 0.04, function()
				ghost(Color3.fromRGB(30, 30, 50))
			end)
		end
		Fx.puff(root.Position - Vector3.new(dir * 1.5, 0, 0), Color3.fromRGB(200, 200, 220), 3, 0.3)
	end

	Movement.onDodge = function()
		for i = 0, 2 do
			task.delay(i * 0.04, function()
				ghost(Color3.fromRGB(210, 215, 240))
			end)
		end
	end

	Movement.onLand = function(position: Vector3, speed: number)
		Fx.puff(position, Color3.fromRGB(170, 165, 170), math.clamp(speed / 20, 2, 5), 0.45)
	end

	Movement.onStep = function(position: Vector3)
		Fx.puff(position, Color3.fromRGB(150, 146, 150), 1.2, 0.35)
	end

	Movement.onDoubleJump = function()
		local root = State.root
		if not root then
			return
		end
		for _, side in { -1, 1 } do
			local wing = Fx.part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3.5, 1.6, 0.3),
				Color = Color3.fromRGB(245, 240, 225),
				Transparency = 0.2,
				CFrame = CFrame.new(root.Position + Vector3.new(side * 2, 0.5, -0.6)) * CFrame.Angles(0, 0, side * 0.5),
			})
			Fx.fade(wing, 0.35, { CFrame = wing.CFrame + Vector3.new(side, -1.5, 0) })
		end
	end
end

return CombatClient
