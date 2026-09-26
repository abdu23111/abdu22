--!strict
-- HollowRun: 2D platformer running in the style of Hollow Knight, for any Roblox character.
--
-- HOW TO USE
--   1. In Roblox Studio, open StarterPlayer > StarterCharacterScripts.
--   2. Insert a LocalScript, name it "HollowRun", and paste this whole file into it.
--   3. Press Play. Works with R6 and R15 characters and with custom rigs that use Motor6Ds
--      with the usual names (Root/RootJoint, Waist, Neck, LeftHip, RightHip, ...).
--
-- WHAT IT DOES
--   Movement (the "feel"):
--     * Instant start and instant stop: no acceleration or sliding.
--     * Instant turn: the character flips to face the other way the same frame.
--     * Full control in the air, at the same speed as on the ground.
--     * Hold jump to jump higher; let go early for a short hop.
--     * Falls faster than it rises, with a capped fall speed, so jumps feel snappy.
--     * Optional: locks movement to one plane (left/right only) with a side-on camera.
--   Animation (procedural, no animation IDs needed):
--     * Quick short-stepped run with a forward lean and a double bob per stride.
--     * A lean-in on the first frames of a run, and a braced skid when you stop.
--     * Idle breathing, legs tucked while rising, dangling while falling, and a squash
--       on landing.
--     * Optional "sprite" timing: the pose updates at a fixed low frame rate for a
--       hand-drawn look (set ANIM_FPS = 0 for smooth motion).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SETTINGS = {
	RUN_SPEED = 26, -- studs per second, the same on the ground and in the air
	JUMP_SPEED = 58, -- upward speed at the start of a jump
	JUMP_CUT = 0.4, -- upward speed is multiplied by this when jump is released early
	FALL_GRAVITY = 1.6, -- gravity multiplier while falling (snappier falls)
	MAX_FALL_SPEED = 95,
	COYOTE_TIME = 0.08, -- you can still jump this long after running off a ledge
	JUMP_BUFFER = 0.1, -- a jump pressed this long before landing still happens

	LOCK_TO_PLANE = true, -- keep the character on one Z plane (a 2D side-scroller)
	SIDE_CAMERA = true, -- side-on camera that follows the character
	CAMERA_DISTANCE = 42,
	CAMERA_HEIGHT = 4,
	CAMERA_FOV = 40,

	ANIM_FPS = 18, -- pose update rate for a hand-drawn look; 0 = smooth every frame
	RUN_CYCLE = 0.34, -- seconds per full stride (two steps)
	DISABLE_DEFAULT_ANIMATIONS = true, -- stop Roblox's default Animate script
}

local player = Players.LocalPlayer
local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local camera = workspace.CurrentCamera

local planeZ = root.Position.Z
local facing = 1 -- +1 = facing +X (right), -1 = facing -X (left)

-- ===========================================================================
-- Default animations off (they would fight the procedural poses)
-- ===========================================================================

if SETTINGS.DISABLE_DEFAULT_ANIMATIONS then
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
end

humanoid.AutoRotate = false
-- The script does the jumping itself; the tiny value keeps the mobile jump button visible.
humanoid.UseJumpPower = true
humanoid.JumpPower = 0.01

-- ===========================================================================
-- Input
-- ===========================================================================

local controls: any = nil
pcall(function()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	controls = playerModule:GetControls()
end)

local function inputX(): number
	local x = 0
	if controls then
		local mv = controls:GetMoveVector()
		x = mv.X
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x = -1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x = 1
	end
	if math.abs(x) < 0.25 then
		return 0
	end
	return if x > 0 then 1 else -1
end

local jumpHeld = false
local jumpPressedAt = -1
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
		jumpHeld = true
		jumpPressedAt = os.clock()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
		jumpHeld = false
	end
end)
-- Touch devices: the on-screen jump button sets Humanoid.Jump.
humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
	if humanoid.Jump and UserInputService.TouchEnabled then
		jumpHeld = true
		jumpPressedAt = os.clock()
		task.delay(0.25, function()
			jumpHeld = false
		end)
	end
end)

-- ===========================================================================
-- Joints: works for R6, R15 and similar custom rigs
-- ===========================================================================

type Joint = { motor: Motor6D, axisRight: Vector3, axisForward: Vector3, toLocal: CFrame, current: CFrame }

local joints: { [string]: Joint } = {}

local ALIASES: { [string]: { string } } = {
	root = { "Root", "RootJoint" },
	waist = { "Waist" },
	neck = { "Neck" },
	hipL = { "LeftHip", "Left Hip" },
	hipR = { "RightHip", "Right Hip" },
	kneeL = { "LeftKnee" },
	kneeR = { "RightKnee" },
	shoulderL = { "LeftShoulder", "Left Shoulder" },
	shoulderR = { "RightShoulder", "Right Shoulder" },
	elbowL = { "LeftElbow" },
	elbowR = { "RightElbow" },
}

local function findJoints()
	table.clear(joints)
	local byName: { [string]: Motor6D } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") then
			byName[d.Name] = d
		end
	end
	for key, names in ALIASES do
		for _, n in names do
			local m = byName[n]
			if m then
				-- Rotations are written in the character's own frame (right = +X, forward =
				-- -Z) and converted into this joint's C0 frame, so every rig type agrees.
				local rot = m.C0.Rotation
				joints[key] = {
					motor = m,
					axisRight = rot:VectorToObjectSpace(Vector3.xAxis),
					axisForward = rot:VectorToObjectSpace(-Vector3.zAxis),
					toLocal = rot:Inverse(),
					current = CFrame.identity,
				}
				break
			end
		end
	end
end
findJoints()
character.DescendantAdded:Connect(function(d)
	if d:IsA("Motor6D") then
		findJoints()
	end
end)

-- A pose for one joint: pitch (degrees, + swings a limb's end forward / tips a body part
-- back), roll (degrees, + raises a limb out to the side) and an offset in studs.
type Pose = { pitch: number?, roll: number?, offset: Vector3? }

local function toTransform(j: Joint, p: Pose, mirror: boolean): CFrame
	local cf = CFrame.identity
	if p.offset then
		cf = CFrame.new(j.toLocal:VectorToWorldSpace(p.offset))
	end
	if p.pitch and p.pitch ~= 0 then
		cf *= CFrame.fromAxisAngle(j.axisRight, math.rad(p.pitch))
	end
	if p.roll and p.roll ~= 0 then
		-- Right-side limbs mirror the roll so "out to the side" means away from the body.
		cf *= CFrame.fromAxisAngle(j.axisForward, math.rad(if mirror then -p.roll else p.roll))
	end
	return cf
end

-- ===========================================================================
-- Poses
-- ===========================================================================

local function runPose(t: number): { [string]: Pose }
	local ph = (t / SETTINGS.RUN_CYCLE) * math.pi * 2
	local s = math.sin(ph)
	local c = math.cos(ph)
	-- Knees fold as each foot swings back and lifts; the body bobs up on every passing step.
	local kneeL = -15 - 55 * math.max(0, -math.sin(ph - 0.6))
	local kneeR = -15 - 55 * math.max(0, math.sin(ph - 0.6))
	return {
		root = { pitch = -11, offset = Vector3.new(0, 0.22 * math.abs(c) - 0.1, 0) },
		waist = { pitch = -4 },
		neck = { pitch = 6 },
		hipL = { pitch = 48 * s },
		hipR = { pitch = -48 * s },
		kneeL = { pitch = kneeL },
		kneeR = { pitch = kneeR },
		-- Arms stay tucked and swing only a little, the way a cloaked runner holds them.
		shoulderL = { pitch = -18 * s - 12, roll = 6 },
		shoulderR = { pitch = 18 * s - 12, roll = 6 },
		elbowL = { pitch = 25 },
		elbowR = { pitch = 25 },
	}
end

local function idlePose(t: number): { [string]: Pose }
	local b = math.sin(t * 2.2)
	return {
		root = { offset = Vector3.new(0, 0.04 * b, 0) },
		waist = { pitch = 1.5 * b },
		neck = { pitch = -1.5 * b },
		shoulderL = { roll = 4 + 2 * b },
		shoulderR = { roll = 4 + 2 * b },
	}
end

local function runStartPose(): { [string]: Pose }
	return {
		root = { pitch = -22, offset = Vector3.new(0, -0.25, 0) },
		hipL = { pitch = 35 },
		hipR = { pitch = -30 },
		kneeR = { pitch = -45 },
		shoulderL = { pitch = -30 },
		shoulderR = { pitch = -30 },
	}
end

local function skidPose(): { [string]: Pose }
	return {
		root = { pitch = 14, offset = Vector3.new(0, -0.3, 0) },
		hipL = { pitch = 38 },
		hipR = { pitch = -15 },
		kneeR = { pitch = -40 },
		neck = { pitch = -8 },
		shoulderL = { pitch = 25, roll = 20 },
		shoulderR = { pitch = 25, roll = 20 },
	}
end

local function risePose(): { [string]: Pose }
	return {
		root = { pitch = -4, offset = Vector3.new(0, 0.1, 0) },
		hipL = { pitch = -15 },
		hipR = { pitch = -35 },
		kneeL = { pitch = -20 },
		kneeR = { pitch = -50 },
		shoulderL = { pitch = -25, roll = 8 },
		shoulderR = { pitch = -25, roll = 8 },
		neck = { pitch = 6 },
	}
end

local function fallPose(t: number): { [string]: Pose }
	local w = math.sin(t * 18) * 3
	return {
		root = { pitch = 4 },
		hipL = { pitch = 18 + w },
		hipR = { pitch = -6 - w },
		kneeL = { pitch = -10 },
		kneeR = { pitch = -25 },
		shoulderL = { pitch = 20, roll = 35 + w },
		shoulderR = { pitch = 20, roll = 35 - w },
		neck = { pitch = -8 },
	}
end

local function landPose(k: number): { [string]: Pose }
	-- k goes 1 -> 0 over the landing.
	return {
		root = { pitch = -8 * k, offset = Vector3.new(0, -0.6 * k, 0) },
		hipL = { pitch = 40 * k },
		hipR = { pitch = 30 * k },
		kneeL = { pitch = -60 * k },
		kneeR = { pitch = -60 * k },
		shoulderL = { roll = 25 * k },
		shoulderR = { roll = 25 * k },
		neck = { pitch = -10 * k },
	}
end

-- ===========================================================================
-- Movement and animation loop
-- ===========================================================================

local lastGroundedAt = 0
local wasGrounded = true
local wasRunning = false
local runStartedAt = -1
local runStoppedAt = -1
local landedAt = -1
local jumpCutDone = true
local animClock = 0
local frameClock = 0

local function grounded(): boolean
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

RunService.Stepped:Connect(function(_, dt)
	if humanoid.Health <= 0 or not root.Parent then
		return
	end
	local now = os.clock()
	local dir = inputX()
	local onGround = grounded()
	local v = root.AssemblyLinearVelocity

	-- Ground bookkeeping.
	if onGround then
		lastGroundedAt = now
		if not wasGrounded and v.Y < -10 then
			landedAt = now
		end
	end
	wasGrounded = onGround

	-- Instant horizontal control, the same in the air.
	local vx = dir * SETTINGS.RUN_SPEED
	local vy = v.Y

	-- Jump (buffered, with coyote time).
	if now - jumpPressedAt <= SETTINGS.JUMP_BUFFER and (onGround or now - lastGroundedAt <= SETTINGS.COYOTE_TIME) and vy < 5 then
		jumpPressedAt = -1
		lastGroundedAt = -1
		vy = SETTINGS.JUMP_SPEED
		jumpCutDone = false
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	-- Releasing jump early cuts the rise short.
	if not jumpCutDone then
		if vy <= 0 then
			jumpCutDone = true
		elseif not jumpHeld then
			vy *= SETTINGS.JUMP_CUT
			jumpCutDone = true
		end
	end
	-- Heavier gravity on the way down, with a capped fall speed.
	if not onGround and vy < 0 then
		vy -= workspace.Gravity * (SETTINGS.FALL_GRAVITY - 1) * dt
	end
	vy = math.max(vy, -SETTINGS.MAX_FALL_SPEED)

	-- Instant turn.
	if dir ~= 0 then
		facing = dir
	end
	local pos = root.Position
	if SETTINGS.LOCK_TO_PLANE then
		pos = Vector3.new(pos.X, pos.Y, planeZ)
	end
	root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(facing, 0, 0))
	root.AssemblyLinearVelocity = Vector3.new(vx, vy, if SETTINGS.LOCK_TO_PLANE then 0 else v.Z)
	humanoid.WalkSpeed = SETTINGS.RUN_SPEED
	humanoid:Move(Vector3.new(dir, 0, 0), false)

	-- Which pose?
	local running = onGround and dir ~= 0
	if running and not wasRunning then
		runStartedAt = now
		animClock = 0
	elseif not running and wasRunning and onGround then
		runStoppedAt = now
	end
	wasRunning = running

	-- "Sprite" timing: only move to a new pose a fixed number of times per second.
	animClock += dt
	frameClock += dt
	local step = if SETTINGS.ANIM_FPS > 0 then 1 / SETTINGS.ANIM_FPS else 0
	if step == 0 or frameClock >= step then
		frameClock = 0
		local t = animClock
		local pose: { [string]: Pose }
		if not onGround then
			pose = if vy > 4 then risePose() else fallPose(now)
		elseif now - landedAt < 0.14 then
			pose = landPose(1 - (now - landedAt) / 0.14)
		elseif running then
			pose = if now - runStartedAt < 0.07 then runStartPose() else runPose(t)
		elseif now - runStoppedAt < 0.14 then
			pose = skidPose()
		else
			pose = idlePose(now)
		end
		for key, j in joints do
			local target = toTransform(j, pose[key] or {}, string.sub(key, -1) == "R")
			if step > 0 then
				j.current = target -- snap: each pose is a held frame
			else
				j.current = j.current:Lerp(target, math.min(1, dt * 22))
			end
		end
	end
	-- Written every frame so nothing else can overwrite the pose in between.
	for _, j in joints do
		j.motor.Transform = j.current
	end
end)

-- ===========================================================================
-- Side-on camera
-- ===========================================================================

if SETTINGS.SIDE_CAMERA then
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = SETTINGS.CAMERA_FOV
	local focus = root.Position
	RunService:BindToRenderStep("HollowRunCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not root.Parent then
			return
		end
		-- Look a little ahead of where the character faces.
		local want = root.Position + Vector3.new(facing * 4, SETTINGS.CAMERA_HEIGHT, 0)
		focus = focus:Lerp(want, math.min(1, dt * 6))
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 1.5, SETTINGS.CAMERA_DISTANCE), focus)
	end)
	humanoid.Died:Connect(function()
		RunService:UnbindFromRenderStep("HollowRunCamera")
	end)
end
