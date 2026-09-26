-- Client half of combat: nail swings with instant feedback (slash arcs, pogo, recoil),
-- focusing Soul to heal, and small flourishes for the dash and double jump.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Hitbox = require(Shared.Hitbox)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)
local Movement = require(script.Parent.Movement)
local CameraController = require(script.Parent.CameraController)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local CombatClient = {}

local lastAttack = -math.huge
local focusing = false
local fxFolder: Folder

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
			local b = zone:FindFirstChild("Breakables")
			if b then
				table.insert(list, b)
			end
		end
	end
	overlap.FilterDescendantsInstances = list
end

local function fadePart(p: BasePart, duration: number, props: { [string]: any }?)
	local goal = props or {}
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(duration, function()
		p:Destroy()
	end)
end

local function fxPart(props: { [string]: any }): Part
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
	p.Parent = fxFolder
	return p
end

-- A crescent of short glowing segments that follows the player for a moment.
local function slashArc(direction: string, reach: number)
	local root = State.root
	if not root then
		return
	end
	local base = if direction == "up" then math.pi / 2 elseif direction == "down" then -math.pi / 2 elseif State.facing > 0 then 0 else math.pi
	local radius = 3.3 * reach
	local segments = {}
	for i = -3, 3 do
		local a = base + math.rad(i * 19)
		local thickness = 0.55 - math.abs(i) * 0.12
		local p = fxPart({
			Size = Vector3.new(thickness, 1.9, 0.3),
			Color = Color3.fromRGB(245, 245, 255),
			Transparency = 0.1,
		})
		table.insert(segments, { part = p, angle = a })
		fadePart(p, 0.16)
	end
	local center = if direction == "side" then Vector3.new(State.facing * 0.8, 0.3, 1.5) else Vector3.new(0, 0, 1.5)
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

local function sparks(at: Vector3)
	for _ = 1, 6 do
		local p = fxPart({
			Size = Vector3.new(0.2, 1.4, 0.2),
			Color = Color3.fromRGB(255, 255, 255),
			CFrame = CFrame.new(at + Vector3.new(0, 0, 2)) * CFrame.Angles(0, 0, math.random() * math.pi * 2),
		})
		local dir = p.CFrame.UpVector
		fadePart(p, 0.22, { CFrame = p.CFrame + dir * 2.5 })
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
	local reach = if State.hasCharm("long_reach") then 1.35 else 1
	Net.event("Attack"):FireServer(direction)
	Sfx.play("slash")
	slashArc(direction, reach)

	refreshTargets()
	local center, size = Hitbox.nail(root.Position, State.facing, direction, reach)
	local hits = workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap)
	if #hits > 0 then
		Sfx.play("hit")
		sparks(center)
		CameraController.shake(0.25)
		if direction == "down" then
			Movement.pogo()
		elseif direction == "side" then
			Movement.recoil(-State.facing, 14, 0.07)
		end
	end
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
			sparks(State.root.Position)
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

function CombatClient.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFx"
	fxFolder.Parent = workspace

	Input.on("attack", attack)
	Input.on("focusStart", focus)

	Movement.onDash = function(dir: number)
		local root = State.root
		if not root then
			return
		end
		for i = 0, 3 do
			task.delay(i * 0.04, function()
				if not root.Parent then
					return
				end
				local ghost = fxPart({
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(2.2, 4.4, 0.4),
					Color = Color3.fromRGB(30, 30, 50),
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.35,
					Position = root.Position + Vector3.new(0, 0, -0.5),
				})
				fadePart(ghost, 0.25)
			end)
		end
		local puff = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 1), Color = Color3.fromRGB(200, 200, 220), Transparency = 0.5, Position = root.Position - Vector3.new(dir * 1.5, 0, -1) })
		fadePart(puff, 0.3, { Size = Vector3.new(6, 5, 1) })
	end

	Movement.onDoubleJump = function()
		local root = State.root
		if not root then
			return
		end
		for _, side in { -1, 1 } do
			local wing = fxPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3.5, 1.6, 0.3),
				Color = Color3.fromRGB(245, 240, 225),
				Transparency = 0.2,
				CFrame = CFrame.new(root.Position + Vector3.new(side * 2, 0.5, -0.6)) * CFrame.Angles(0, 0, side * 0.5),
			})
			fadePart(wing, 0.35, { CFrame = wing.CFrame + Vector3.new(side, -1.5, 0) })
		end
	end
end

return CombatClient
