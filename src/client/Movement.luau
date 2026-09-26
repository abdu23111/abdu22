-- Side-scrolling character controller: tight running and jumping with coyote time,
-- jump buffering and variable height, plus the dash, wall cling and double jump abilities.
-- Also handles doorways between zones, hazard respawns and knockback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)
local Fade = require(script.Parent.Fade)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local Movement = {}
Movement.onTeleport = nil :: (() -> ())?
Movement.onDash = nil :: ((number) -> ())?
Movement.onDoubleJump = nil :: (() -> ())?

local jumpPressedAt = -1
local jumpCutArmed = false
local lastGroundedAt = 0
local groundIgnoreUntil = 0
local jumpedSinceGround = false
local usedDouble = false
local dashReady = true
local dashRequestedAt = -1
local dashUntil = 0
local dashDir = 1
local dashCooldownUntil = 0
local lockUntil, lockDir, lockSpeed = 0, 0, 0
local rooted = false
local wasGrounded = false
local lastSafe: Vector3? = nil
local lastSafeCheck = 0
local doorCooldownUntil = 0

local world = workspace:WaitForChild("World")
local doorsFolder = world:WaitForChild("Doors")

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
local hazardParams = OverlapParams.new()
hazardParams.FilterType = Enum.RaycastFilterType.Include

local function refreshFilters()
	local solids, hazards = {}, {}
	for _, zone in world:GetChildren() do
		if zone:IsA("Folder") and zone.Name:sub(1, 5) == "Zone_" then
			for _, name in { "Map", "Breakables" } do
				local f = zone:FindFirstChild(name)
				if f then
					table.insert(solids, f)
				end
			end
			local h = zone:FindFirstChild("Hazards")
			if h then
				table.insert(hazards, h)
			end
		end
	end
	wallParams.FilterDescendantsInstances = solids
	hazardParams.FilterDescendantsInstances = hazards
end

-- ===== Public API used by combat and focus =====

function Movement.pogo()
	local root = State.root
	if not root then
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.POGO_VELOCITY, 0)
	usedDouble = false
	dashReady = true
	dashUntil = 0
	jumpCutArmed = false
	groundIgnoreUntil = os.clock() + 0.1
end

function Movement.recoil(dir: number, speed: number, duration: number)
	lockUntil = os.clock() + duration
	lockDir = dir
	lockSpeed = speed
end

function Movement.setRooted(on: boolean)
	rooted = on
end

function Movement.teleport(position: Vector3, facing: number?)
	local character, root = State.character, State.root
	if not character or not root then
		return
	end
	State.facing = facing or State.facing
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(State.facing, 0, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	dashUntil, lockUntil = 0, 0
	if Movement.onTeleport then
		Movement.onTeleport()
	end
end

local function flicker()
	local character = State.character
	if not character then
		return
	end
	local untilTime = os.clock() + Config.INVULN_TIME
	task.spawn(function()
		local on = false
		while os.clock() < untilTime and character.Parent do
			on = not on
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if on then 0.6 else 0
				end
			end
			task.wait(0.08)
		end
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end)
end

-- ===== Frame step =====

local function keepPlane(root: BasePart)
	local p = root.Position
	if math.abs(p.Z) > 0.05 or root.CFrame.LookVector.X * State.facing < 0.98 then
		root.CFrame = CFrame.lookAt(Vector3.new(p.X, p.Y, 0), Vector3.new(p.X + State.facing, p.Y, 0))
	end
end

local function transition(door: BasePart)
	local digit = door:GetAttribute("Door")
	local zone = door:GetAttribute("Zone")
	local target: BasePart? = nil
	for _, other in doorsFolder:GetChildren() do
		if other ~= door and other:GetAttribute("Door") == digit and other:GetAttribute("Zone") ~= zone then
			target = other :: BasePart
		end
	end
	if not target then
		return
	end
	doorCooldownUntil = math.huge
	State.freeze("door", true)
	task.spawn(function()
		Fade.out(0.3)
		local arrival = target:GetAttribute("Arrival") :: Vector3
		Movement.teleport(arrival, if arrival.X > target.Position.X then 1 else -1)
		lastSafe = arrival
		task.wait(0.15)
		State.freeze("door", false)
		doorCooldownUntil = os.clock() + 1
		Fade.into(0.4)
	end)
end

local function step()
	local humanoid, root = State.humanoid, State.root
	if not humanoid or not root or not humanoid.Parent then
		return
	end
	local now = os.clock()
	local v = root.AssemblyLinearVelocity

	if State.frozen() or rooted then
		humanoid:Move(Vector3.zero)
		root.AssemblyLinearVelocity = Vector3.new(0, math.max(v.Y, -Config.MAX_FALL_SPEED), 0)
		keepPlane(root)
		return
	end

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air and now >= groundIgnoreUntil
	if grounded then
		if not wasGrounded and v.Y < -45 then
			Sfx.play("land")
		end
		lastGroundedAt = now
		usedDouble = false
		dashReady = true
		jumpedSinceGround = false
	end
	wasGrounded = grounded
	State.grounded = grounded

	local input = Input.axis()
	local locked = now < lockUntil
	local moveDir = if locked then lockDir else input
	local dashing = now < dashUntil

	-- Wall cling
	local wallDir = 0
	if State.hasAbility("HasClaws") and not grounded and not dashing and not locked and input ~= 0 then
		local hit = workspace:Raycast(root.Position, Vector3.new(input * 1.9, 0, 0), wallParams)
		if hit and not hit.Instance:GetAttribute("NoCling") then
			wallDir = input
		end
	end
	if wallDir ~= 0 then
		usedDouble = false
		dashReady = true
		if v.Y < -Config.WALL_SLIDE_SPEED then
			v = Vector3.new(v.X, -Config.WALL_SLIDE_SPEED, 0)
		end
		State.facing = -wallDir
	elseif moveDir ~= 0 and not dashing then
		State.facing = moveDir
	end

	-- Jumping (buffered)
	if now - jumpPressedAt <= Config.JUMP_BUFFER then
		local canGroundJump = grounded or (now - lastGroundedAt <= Config.COYOTE_TIME and not jumpedSinceGround)
		local jumped = false
		if canGroundJump then
			v = Vector3.new(v.X, Config.JUMP_VELOCITY, 0)
			jumpedSinceGround = true
			jumped = true
		elseif wallDir ~= 0 then
			v = Vector3.new(-wallDir * Config.WALL_JUMP_PUSH, Config.JUMP_VELOCITY, 0)
			Movement.recoil(-wallDir, Config.WALL_JUMP_PUSH, Config.WALL_JUMP_LOCK)
			State.facing = -wallDir
			jumped = true
		elseif State.hasAbility("HasWings") and not usedDouble and not grounded then
			usedDouble = true
			v = Vector3.new(v.X, Config.JUMP_VELOCITY * 0.95, 0)
			jumped = true
			if Movement.onDoubleJump then
				Movement.onDoubleJump()
			end
		end
		if jumped then
			jumpPressedAt = -1
			jumpCutArmed = true
			groundIgnoreUntil = now + 0.12
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			Sfx.play("jump")
		end
	end

	-- Releasing jump early cuts the arc short.
	if jumpCutArmed then
		if v.Y <= 0 then
			jumpCutArmed = false
		elseif not Input.jumpHeld then
			v = Vector3.new(v.X, v.Y * Config.JUMP_CUT, 0)
			jumpCutArmed = false
		end
	end

	-- Dash
	if now - dashRequestedAt <= 0.1 and State.hasAbility("HasDash") and dashReady and now >= dashCooldownUntil and not locked then
		dashRequestedAt = -1
		dashDir = if wallDir ~= 0 then -wallDir else State.facing
		State.facing = dashDir
		dashUntil = now + Config.DASH_TIME
		dashCooldownUntil = now + Config.DASH_COOLDOWN
		if not grounded then
			dashReady = false
		end
		dashing = true
		Sfx.play("dash")
		if Movement.onDash then
			Movement.onDash(dashDir)
		end
	end

	local baseSpeed = Config.WALK_SPEED * (if State.hasCharm("swift_mantle") then 1.15 else 1)
	if dashing then
		v = Vector3.new(dashDir * Config.DASH_SPEED, 0, 0)
		humanoid.WalkSpeed = Config.DASH_SPEED
		humanoid:Move(Vector3.new(dashDir, 0, 0))
	elseif locked then
		v = Vector3.new(lockDir * lockSpeed, v.Y, 0)
		humanoid.WalkSpeed = lockSpeed
		humanoid:Move(Vector3.new(lockDir, 0, 0))
	else
		humanoid.WalkSpeed = baseSpeed
		humanoid:Move(Vector3.new(moveDir, 0, 0))
	end

	v = Vector3.new(v.X, math.max(v.Y, -Config.MAX_FALL_SPEED), 0)
	root.AssemblyLinearVelocity = v
	keepPlane(root)

	-- Remember the last safe footing for thorn respawns.
	if grounded and not dashing and now - lastSafeCheck > 0.2 then
		lastSafeCheck = now
		local near = workspace:GetPartBoundsInBox(CFrame.new(root.Position - Vector3.new(0, 2.5, 0)), Vector3.new(7, 5, 6), hazardParams)
		if #near == 0 then
			lastSafe = root.Position
		end
	end

	-- Doorways
	if now >= doorCooldownUntil then
		for _, door in doorsFolder:GetChildren() do
			if door:IsA("BasePart") and door:GetAttribute("Door") then
				local d = root.Position - door.Position
				if math.abs(d.X) < door.Size.X / 2 + 0.6 and math.abs(d.Y) < door.Size.Y / 2 then
					transition(door)
					break
				end
			end
		end
	end
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	State.character, State.humanoid, State.root = character, humanoid, root
	humanoid.AutoRotate = false
	for _, s in {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated,
	} do
		humanoid:SetStateEnabled(s, false)
	end
	State.facing = 1
	lastSafe = nil
	rooted = false
	refreshFilters()
	State.freeze("dead", false)
	State.freeze("hazard", false)
	State.freeze("door", false)
	doorCooldownUntil = os.clock() + 1
	task.defer(function()
		if Movement.onTeleport then
			Movement.onTeleport()
		end
	end)
end

function Movement.init()
	-- Take over from Roblox's default walking controls.
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and playerModule then
		playerModule:GetControls():Disable()
	end

	Input.on("jump", function()
		jumpPressedAt = os.clock()
	end)
	Input.on("dash", function()
		dashRequestedAt = os.clock()
	end)

	Net.event("Knockback").OnClientEvent:Connect(function(dirX: number)
		local root = State.root
		if not root then
			return
		end
		Sfx.play("hurt")
		dashUntil = 0
		Movement.recoil(dirX, Config.KNOCKBACK.X, 0.16)
		root.AssemblyLinearVelocity = Vector3.new(dirX * Config.KNOCKBACK.X, Config.KNOCKBACK.Y, 0)
		flicker()
	end)

	Net.event("HazardRespawn").OnClientEvent:Connect(function()
		Sfx.play("hurt")
		State.freeze("hazard", true)
		task.spawn(function()
			Fade.out(0.2)
			local root = State.root
			if root then
				Movement.teleport(lastSafe or root.Position + Vector3.new(0, 6, 0))
			end
			task.wait(0.2)
			State.freeze("hazard", false)
			flicker()
			Fade.into(0.3)
		end)
	end)

	Net.event("Died").OnClientEvent:Connect(function()
		State.freeze("dead", true)
		task.spawn(function()
			Fade.out(1.2, Color3.fromRGB(8, 6, 14))
			player.CharacterAdded:Wait()
			task.wait(0.4)
			Fade.into(1)
		end)
	end)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.PreSimulation:Connect(step)
end

return Movement
