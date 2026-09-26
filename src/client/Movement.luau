-- Third-person character controller. Movement is relative to the camera; jumps use coyote
-- time, buffering and variable height; the Drift Cloak dashes, the Sidestep dodges with
-- brief invulnerability, Thorn Claws cling to any rough wall and Veil Wings give a second
-- jump. The Silkline swings from glowing rings. Also handles doorways between regions,
-- hazard respawns and knockback.

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
Movement.onTeleport = nil :: ((Vector3?) -> ())?
Movement.onDash = nil :: ((Vector3) -> ())?
Movement.onDoubleJump = nil :: (() -> ())?
Movement.onDodge = nil :: ((Vector3) -> ())?
Movement.onLand = nil :: ((Vector3, number) -> ())?
Movement.onStep = nil :: ((Vector3) -> ())?
Movement.onJump = nil :: (() -> ())?
Movement.onHurt = nil :: (() -> ())?
Movement.onWallJump = nil :: ((Vector3) -> ())?
Movement.onSwing = nil :: ((Vector3?) -> ())? -- anchor when a swing starts, nil when it ends

local jumpPressedAt = -1
local jumpCutArmed = false
local lastGroundedAt = 0
local groundIgnoreUntil = 0
local jumpedSinceGround = false
local usedDouble = false
local dashReady = true
local dashRequestedAt = -1
local dashUntil = 0
local dashDir = Vector3.xAxis
local dashCooldownUntil = 0
local dodgeRequestedAt = -1
local dodgeUntil = 0
local dodgeDir = Vector3.xAxis
local dodgeCooldownUntil = 0
local lockUntil = 0
local lockVelocity = Vector3.zero
local rooted = false
local wasGrounded = false
local lastSafe: Vector3? = nil
local lastSafeCheck = 0
local doorCooldownUntil = 0
local lastStepDust = 0
local wallNormal: Vector3? = nil
local swing: { anchor: Vector3, length: number }? = nil
local swingCooldownUntil = 0
local swingSpent = false -- each press of the swing button catches at most one ring
local anchors: { BasePart } = {}

local world = workspace:WaitForChild("World")
local doorsFolder = world:WaitForChild("Doors")

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
local hazardParams = OverlapParams.new()
hazardParams.FilterType = Enum.RaycastFilterType.Include

local function refreshFilters()
	local solids, hazards = { workspace.Terrain }, {}
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
	table.clear(anchors)
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SwingAnchor" then
			table.insert(anchors, d)
		end
	end
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.zero
end

-- World-space movement direction from the stick and the camera's heading.
function Movement.moveWorld(): Vector3
	local mv = Input.move()
	if Config.SIDE_VIEW then
		-- Left and right along the play plane; up/down only aims.
		return if math.abs(mv.X) > 0.2 then Vector3.new(math.sign(mv.X), 0, 0) else Vector3.zero
	end
	if mv.Magnitude < 0.05 then
		return Vector3.zero
	end
	local yaw = State.cameraYaw
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local v = right * mv.X + forward * mv.Y
	return if v.Magnitude > 1 then v.Unit else v
end

-- ===== Public API used by combat and focus =====

function Movement.pogo()
	local root = State.root
	if not root then
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.POGO_VELOCITY, v.Z)
	usedDouble = false
	dashReady = true
	dashUntil = 0
	jumpCutArmed = false
	groundIgnoreUntil = os.clock() + 0.1
end

-- Push the character along `velocity` for a moment, overriding input.
function Movement.shove(velocity: Vector3, duration: number)
	lockUntil = os.clock() + duration
	lockVelocity = Vector3.new(velocity.X, 0, velocity.Z)
end

-- Recoil along the facing direction (negative pushes backwards).
function Movement.recoil(dir: number, speed: number, duration: number)
	Movement.shove(State.facingVector * dir * speed, duration)
end

function Movement.setRooted(on: boolean)
	rooted = on
end

-- ===== Silkline swinging =====

local function nearestAnchor(pos: Vector3): BasePart?
	local best, bestD = nil, Config.SWING_RANGE
	for _, a in anchors do
		local d = (a.Position - pos).Magnitude
		-- Rings below you can't hold you up.
		if d < bestD and a.Position.Y > pos.Y - 1 then
			best, bestD = a, d
		end
	end
	return best
end

local function endSwing(withJump: boolean)
	local humanoid, root = State.humanoid, State.root
	swing = nil
	State.swingAnchor = nil
	swingCooldownUntil = os.clock() + 0.25
	if Movement.onSwing then
		Movement.onSwing(nil)
	end
	if not humanoid or not root then
		return
	end
	humanoid.PlatformStand = false
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local v = root.AssemblyLinearVelocity
	local lift = Config.SWING_RELEASE_LIFT + (if withJump then 16 else 0)
	v = Vector3.new(v.X * 1.08, math.max(v.Y, 0) + lift, v.Z * 1.08)
	root.AssemblyLinearVelocity = v
	-- Keep the swing's momentum for a moment instead of snapping to walking speed.
	Movement.shove(v, 0.45)
	usedDouble = false
	dashReady = true
	jumpedSinceGround = true
	jumpCutArmed = false
	groundIgnoreUntil = os.clock() + 0.1
	if withJump then
		jumpPressedAt = -1
		Sfx.play("jump", 1.15)
	end
end

local function startSwing(anchor: BasePart)
	local humanoid, root = State.humanoid, State.root
	if not humanoid or not root then
		return
	end
	local d = (root.Position - anchor.Position).Magnitude
	swing = { anchor = anchor.Position, length = math.clamp(d, Config.SWING_MIN_ROPE, Config.SWING_MAX_ROPE) }
	State.swingAnchor = anchor.Position
	dashUntil, dodgeUntil, lockUntil = 0, 0, 0
	wallNormal = nil
	humanoid.PlatformStand = true
	-- Carry the approach speed into the swing, with a little kick the way you're facing.
	root.AssemblyLinearVelocity += State.facingVector * 10
	Sfx.play("dash", 1.5)
	if Movement.onSwing then
		Movement.onSwing(anchor.Position)
	end
end

-- One physics step on the rope: gravity (from the engine) swings you; holding a direction
-- pumps the swing; the rope stops you drifting further than its length from the ring.
local function swingStep(dt: number, root: BasePart)
	local s = swing :: { anchor: Vector3, length: number }
	local r = root.Position - s.anchor
	local d = r.Magnitude
	if d < 1e-3 then
		return
	end
	local n = r / d
	local v = root.AssemblyLinearVelocity
	local move = Movement.moveWorld()
	local tangent = move - n * move:Dot(n)
	v += tangent * Config.SWING_PUMP * dt
	-- The rope reels in a little toward a comfortable length.
	s.length = math.max(Config.SWING_MIN_ROPE, s.length - dt * 3)
	if d > s.length then
		local outward = v:Dot(n)
		if outward > 0 then
			v -= n * outward
		end
		local fixed = s.anchor + n * s.length
		local look = Vector3.new(v.X, 0, v.Z)
		if look.Magnitude < 1 then
			look = State.facingVector
		end
		root.CFrame = CFrame.lookAt(fixed, fixed + look.Unit)
	end
	if v.Magnitude > Config.SWING_MAX_SPEED then
		v = v.Unit * Config.SWING_MAX_SPEED
	end
	if Config.SIDE_VIEW then
		v = Vector3.new(v.X, v.Y, 0)
		local p = root.Position
		if math.abs(p.Z) > 0.02 then
			root.CFrame = root.CFrame - Vector3.new(0, 0, p.Z)
		end
	end
	root.AssemblyLinearVelocity = v
	root.AssemblyAngularVelocity = Vector3.zero
	State.action = "swing"
	State.moveSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
end

function Movement.teleport(position: Vector3, facing: Vector3?)
	local character, root = State.character, State.root
	if not character or not root then
		return
	end
	if swing then
		endSwing(false)
	end
	local f = facing or State.facingVector
	character:PivotTo(CFrame.lookAt(position, position + f))
	root.AssemblyLinearVelocity = Vector3.zero
	dashUntil, lockUntil, dodgeUntil = 0, 0, 0
	if Movement.onTeleport then
		Movement.onTeleport(f)
	end
end

local function flicker()
	State.invulnUntil = os.clock() + Config.INVULN_TIME
end

-- ===== Frame step =====

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
	Sfx.play("door")
	task.spawn(function()
		Fade.out(0.3)
		local arrival = target:GetAttribute("Arrival") :: Vector3
		local inward = (target:GetAttribute("Inward") or 1) :: number
		Movement.teleport(arrival, Vector3.new(inward, 0, 0))
		lastSafe = arrival
		task.wait(0.15)
		State.freeze("door", false)
		doorCooldownUntil = os.clock() + 1
		Fade.into(0.4)
	end)
end

local function step(dt: number)
	local humanoid, root = State.humanoid, State.root
	if not humanoid or not root or not humanoid.Parent then
		return
	end
	local now = os.clock()
	local facing = flat(root.CFrame.LookVector)
	State.facingVector = if facing.Magnitude > 0.5 then facing else Vector3.xAxis

	-- Swinging takes over completely until the rope is let go.
	if swing then
		if State.frozen() or humanoid.Health <= 0 then
			endSwing(false)
		elseif now - jumpPressedAt <= Config.JUMP_BUFFER then
			endSwing(true)
		elseif not Input.swingHeld then
			endSwing(false)
		else
			swingStep(dt, root)
			State.grounded = false
			wasGrounded = false
			return
		end
	elseif Input.swingHeld and not swingSpent and now >= swingCooldownUntil and not State.frozen() and not rooted then
		-- Holding the button catches the first ring that comes within reach.
		local anchor = nearestAnchor(root.Position)
		if anchor then
			swingSpent = true
			startSwing(anchor)
			return
		end
	end
	local v = root.AssemblyLinearVelocity

	if State.frozen() or rooted then
		humanoid:Move(Vector3.zero)
		root.AssemblyLinearVelocity = Vector3.new(0, math.max(v.Y, -Config.MAX_FALL_SPEED), 0)
		State.moveSpeed = 0
		State.action = if rooted then "heal" else nil
		return
	end

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air and now >= groundIgnoreUntil
	if grounded then
		if not wasGrounded then
			if v.Y < -45 then
				Sfx.play("land")
			end
			if v.Y < -20 and Movement.onLand then
				Movement.onLand(root.Position - Vector3.new(0, 3, 0), -v.Y)
			end
		end
		lastGroundedAt = now
		usedDouble = false
		dashReady = true
		jumpedSinceGround = false
	end
	wasGrounded = grounded
	State.grounded = grounded

	local move = Movement.moveWorld()
	local locked = now < lockUntil
	local dashing = now < dashUntil
	local dodging = now < dodgeUntil

	-- Face the lock-on target; otherwise the Humanoid turns toward the direction of travel.
	local target = State.lockTarget
	if target and target.Parent and not dashing and not dodging then
		humanoid.AutoRotate = false
		local to = flat(target.Position - root.Position)
		if to.Magnitude > 0 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + to)
		end
	else
		humanoid.AutoRotate = not (dashing or dodging or wallNormal ~= nil)
	end

	-- Wall cling: jump into a rough wall while holding toward it.
	wallNormal = nil
	-- Wall slide and wall jump are always available (the Thorn Claws are no longer needed).
	if not grounded and not dashing and not locked and move.Magnitude > 0.3 then
		local hit = workspace:Raycast(root.Position, move.Unit * 2.2, wallParams)
		if hit and math.abs(hit.Normal.Y) < 0.4 and not hit.Instance:GetAttribute("NoCling") then
			wallNormal = flat(hit.Normal)
		end
	end
	if wallNormal then
		usedDouble = false
		dashReady = true
		if v.Y < -Config.WALL_SLIDE_SPEED then
			v = Vector3.new(v.X, -Config.WALL_SLIDE_SPEED, v.Z)
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + wallNormal)
	end

	-- Jumping (buffered)
	if now - jumpPressedAt <= Config.JUMP_BUFFER then
		local canGroundJump = grounded or (now - lastGroundedAt <= Config.COYOTE_TIME and not jumpedSinceGround)
		local jumped = false
		if canGroundJump then
			v = Vector3.new(v.X, Config.JUMP_VELOCITY, v.Z)
			jumpedSinceGround = true
			jumped = true
			if Movement.onJump then
				Movement.onJump()
			end
		elseif wallNormal then
			local push = wallNormal * Config.WALL_JUMP_PUSH
			v = Vector3.new(push.X, Config.JUMP_VELOCITY, push.Z)
			Movement.shove(push, Config.WALL_JUMP_LOCK)
			jumped = true
			-- Face away from the wall as you kick off it.
			root.CFrame = CFrame.lookAt(root.Position, root.Position + wallNormal)
			if Movement.onWallJump then
				Movement.onWallJump(wallNormal)
			end
		elseif State.hasAbility("HasWings") and not usedDouble and not grounded then
			usedDouble = true
			v = Vector3.new(v.X, Config.JUMP_VELOCITY * 0.95, v.Z)
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
			v = Vector3.new(v.X, v.Y * Config.JUMP_CUT, v.Z)
			jumpCutArmed = false
		end
	end

	-- Dash
	if now - dashRequestedAt <= 0.1 and State.hasAbility("HasDash") and dashReady and now >= dashCooldownUntil and not locked then
		dashRequestedAt = -1
		dashDir = if wallNormal then wallNormal elseif move.Magnitude > 0.2 then move.Unit else State.facingVector
		dashUntil = now + Config.DASH_TIME
		dashCooldownUntil = now + Config.DASH_COOLDOWN
		if not grounded then
			dashReady = false
		end
		dashing = true
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dashDir)
		Sfx.play("dash")
		if Movement.onDash then
			Movement.onDash(dashDir)
		end
	end

	-- Sidestep: a quick hop (backwards unless a direction is held) with brief invulnerability.
	if now - dodgeRequestedAt <= 0.1 and now >= dodgeCooldownUntil and not dashing and not locked then
		dodgeRequestedAt = -1
		dodgeDir = if move.Magnitude > 0.2 then move.Unit else -State.facingVector
		dodgeUntil = now + Config.DODGE_TIME
		dodgeCooldownUntil = now + Config.DODGE_COOLDOWN
		dodging = true
		Net.event("Dodge"):FireServer()
		Sfx.play("dodge", 1.25)
		if Movement.onDodge then
			Movement.onDodge(dodgeDir)
		end
	end

	local baseSpeed = Config.WALK_SPEED * (if State.hasCharm("swift_mantle") then 1.15 else 1)
	if dodging then
		local d = dodgeDir * Config.DODGE_SPEED
		v = Vector3.new(d.X, if grounded then math.max(v.Y, 8) else v.Y * 0.4, d.Z)
		humanoid.WalkSpeed = Config.DODGE_SPEED
		humanoid:Move(dodgeDir)
		State.action = "dodge"
	elseif dashing then
		local d = dashDir * Config.DASH_SPEED
		v = Vector3.new(d.X, 0, d.Z)
		humanoid.WalkSpeed = Config.DASH_SPEED
		humanoid:Move(dashDir)
		State.action = "dash"
	elseif locked then
		v = Vector3.new(lockVelocity.X, v.Y, lockVelocity.Z)
		humanoid.WalkSpeed = lockVelocity.Magnitude
		humanoid:Move(flat(lockVelocity))
		State.action = nil
	else
		humanoid.WalkSpeed = baseSpeed
		humanoid:Move(move)
		State.action = if wallNormal then "wall" else nil
		-- Walking into a wall on the ground: lean into it instead of running on the spot.
		if not wallNormal and grounded and move.Magnitude > 0.5 then
			local ahead = workspace:Raycast(root.Position - Vector3.new(0, 1.5, 0), move.Unit * 2.2, wallParams)
			if ahead and math.abs(ahead.Normal.Y) < 0.4 then
				State.action = "push"
			end
		end
	end

	v = Vector3.new(v.X, math.max(v.Y, -Config.MAX_FALL_SPEED), v.Z)
	if Config.SIDE_VIEW then
		-- Stay on the play plane and face straight left or right.
		v = Vector3.new(v.X, v.Y, 0)
		local p = root.Position
		local look = root.CFrame.LookVector
		if math.abs(p.Z) > 0.02 or math.abs(look.Z) > 0.02 then
			local fx = if math.abs(look.X) > 0.05 then math.sign(look.X) else State.facingVector.X
			if fx == 0 then
				fx = 1
			end
			local planar = Vector3.new(p.X, p.Y, 0)
			root.CFrame = CFrame.lookAt(planar, planar + Vector3.new(fx, 0, 0))
		end
	end
	root.AssemblyLinearVelocity = v
	State.moveSpeed = Vector3.new(v.X, 0, v.Z).Magnitude

	if grounded and State.moveSpeed > 12 and now - lastStepDust > 0.22 and Movement.onStep then
		lastStepDust = now
		Movement.onStep(root.Position - Vector3.new(0, 3, 0) - State.facingVector * 0.8)
	end

	-- Remember the last safe footing for thorn respawns.
	if grounded and not dashing and now - lastSafeCheck > 0.2 then
		lastSafeCheck = now
		local near = workspace:GetPartBoundsInBox(CFrame.new(root.Position - Vector3.new(0, 2.5, 0)), Vector3.new(7, 5, 7), hazardParams)
		if #near == 0 then
			lastSafe = root.Position
		end
	end

	-- Doorways
	if now >= doorCooldownUntil then
		for _, door in doorsFolder:GetChildren() do
			if door:IsA("BasePart") and door:GetAttribute("Door") then
				local d = root.Position - door.Position
				local half = door.Size / 2
				if math.abs(d.X) < half.X + 0.6 and math.abs(d.Y) < half.Y and math.abs(d.Z) < half.Z then
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
	humanoid.AutoRotate = true
	for _, s in {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated,
	} do
		humanoid:SetStateEnabled(s, false)
	end
	lastSafe = nil
	rooted = false
	swing = nil
	State.swingAnchor = nil
	refreshFilters()
	State.freeze("dead", false)
	State.freeze("hazard", false)
	State.freeze("door", false)
	State.lockTarget = nil
	doorCooldownUntil = os.clock() + 1
	task.defer(function()
		if Movement.onTeleport then
			Movement.onTeleport(nil)
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
	Input.on("dodge", function()
		dodgeRequestedAt = os.clock()
	end)
	Input.on("swingRelease", function()
		swingSpent = false
	end)

	Net.event("Knockback").OnClientEvent:Connect(function(direction: Vector3)
		local root = State.root
		if not root then
			return
		end
		Sfx.play("hurt")
		dashUntil = 0
		if swing then
			endSwing(false)
		end
		local push = flat(direction) * Config.KNOCKBACK.X
		Movement.shove(push, 0.16)
		root.AssemblyLinearVelocity = Vector3.new(push.X, Config.KNOCKBACK.Y, push.Z)
		flicker()
		if Movement.onHurt then
			Movement.onHurt()
		end
	end)

	Net.event("HazardRespawn").OnClientEvent:Connect(function()
		Sfx.play("hurt")
		if swing then
			endSwing(false)
		end
		State.freeze("hazard", true)
		if Movement.onHurt then
			Movement.onHurt()
		end
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
		State.dead = true
		task.spawn(function()
			task.wait(1.1)
			Fade.out(1.0, Color3.fromRGB(8, 6, 14))
			player.CharacterAdded:Wait()
			State.dead = false
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
