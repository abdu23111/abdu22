-- Draws every player as the animated Wanderer rig and decides, every frame, which clip it
-- should be playing. The local player's animation follows the movement and combat state
-- directly; other players are animated from their velocity and the attributes the server
-- sets on their character (Swing, HurtAt, Dead).
--
-- How clips are chosen:
--   * One-shots (attacks, hurt, jump take-off, landing, dodge, turn, start/stop running,
--     idle glances) play over locomotion. A one-shot can only be interrupted by one of equal
--     or higher priority, and "soft" one-shots (transitions, idle glances) are cancelled the
--     moment they stop making sense (you start moving, leave the ground...).
--   * Locomotion: idle when standing still, run (playback matched to ground speed so the
--     feet don't slide) when moving, rise / apex / fall in the air, plus the ability states
--     (dash, dodge, wall slide, swing, heal, charge, sit).
--   * Transitions: starting and stopping a run, turning around, landing (scaled by how hard),
--     kicking off walls, and an occasional idle glance when you stand around.
--   * The head turns toward nearby points of interest (people, items, creatures).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.Rig)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local localPlayer = Players.LocalPlayer

local Characters = {}

-- The hero is drawn a little larger than the Humanoid underneath, so it reads clearly on screen.
local HERO_SCALE = 1.3
Characters.HERO_SCALE = HERO_SCALE

type Entry = {
	rig: any,
	character: Model,
	isLocal: boolean,
	facing: Vector3,
	facingSign: number,
	theta: number,
	oneShot: string?,
	oneShotAt: number,
	oneShotAirborne: boolean,
	priority: number,
	flash: number,
	airborne: boolean,
	moving: boolean,
	fastest: number,
	idleSince: number,
	nextGlance: number,
	lookRefresh: number,
	dead: boolean,
}

local entries: { [Model]: Entry } = {}
local localEntry: Entry? = nil
local hitStopUntil = 0
local fxFolder: Folder

local SWING_CLIPS = {
	side = "attackSide",
	side2 = "attackSide2",
	finish = "attackFinish",
	up = "attackUp",
	down = "attackDown",
	cleave = "cleave",
	bolt = "bolt",
}

-- Higher priority one-shots can interrupt lower ones; 1 and below are soft transitions.
local PRIORITY = {
	death = 6,
	hurt = 5,
	cleave = 4,
	attackFinish = 4,
	attackSide = 3,
	attackSide2 = 3,
	attackUp = 3,
	attackDown = 3,
	bolt = 3,
	shriek = 3,
	flip = 2,
	dodge = 2,
	wallJump = 2,
	land = 1,
	jumpStart = 1,
	runStart = 1,
	runStop = 1,
	turn = 1,
	idleLook = 0.5,
}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.xAxis
end

local function play(entry: Entry, clip: string, speed: number?)
	if entry.dead and clip ~= "death" then
		return
	end
	local p = PRIORITY[clip] or 1
	if entry.oneShot and not entry.rig:finished() and p < entry.priority then
		return
	end
	if not entry.rig:has(clip) then
		return
	end
	entry.oneShot = clip
	entry.oneShotAt = os.clock()
	entry.oneShotAirborne = entry.airborne
	entry.priority = p
	-- Attacks snap in (their windup is the anticipation); transitions blend.
	entry.rig:play(clip, if p >= 3 then 0.04 elseif p >= 1 then 0.07 else 0.25, speed or 1, true)
end

-- One-shot actions for the local player (called by combat and movement).
function Characters.action(clip: string, speed: number?)
	if localEntry then
		play(localEntry, clip, speed)
	end
end

function Characters.flash(amount: number)
	if localEntry then
		localEntry.flash = amount
	end
end

-- Impact frame: freeze the local character's pose for a moment when a strike lands.
function Characters.hitStop(duration: number)
	hitStopUntil = math.max(hitStopUntil, os.clock() + duration)
end

function Characters.localRig(): any?
	return localEntry and localEntry.rig
end

-- ===== Points of interest for the head to glance at =====

local poi: { BasePart } = {}
local poiRefreshedAt = 0

local function refreshPoi()
	table.clear(poi)
	local world = workspace:FindFirstChild("World")
	if world then
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "NPCAnchor" or d.Name == "Pickup" or d.Name == "SwingAnchor") then
				table.insert(poi, d)
			end
		end
	end
end

local function lookTargetFor(root: BasePart, facingSign: number): Vector3?
	local best, bestD = nil, 18
	local pos = root.Position
	local function consider(p: Vector3)
		local d = (p - pos).Magnitude
		-- Mostly things ahead; something very close behind is still worth a glance.
		if (p.X - pos.X) * facingSign < -2 and d > 8 then
			return
		end
		if d < bestD then
			best, bestD = p, d
		end
	end
	for _, part in poi do
		if part.Parent and part.LocalTransparencyModifier < 0.5 then
			consider(part.Position)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, model in enemies:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart and not model:GetAttribute("Dead") then
				consider(model.PrimaryPart.Position)
			end
		end
	end
	return best
end

-- ===== Building =====

local function build(character: Model)
	if entries[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local isLocal = character == localPlayer.Character
	local rig = Rig.new("wanderer", fxFolder, HERO_SCALE)
	-- The lantern at the hip lights the way (and casts shadows for your own character).
	for _, part in rig:partsWithTag("glow") do
		if part.Material == Enum.Material.Neon and part.Color.R > part.Color.B then
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 214, 160)
			light.Shadows = isLocal
			light.Parent = part
			break
		end
	end
	local look = flat((root :: BasePart).CFrame.LookVector)
	local entry: Entry = {
		rig = rig,
		character = character,
		isLocal = isLocal,
		facing = look,
		facingSign = if look.X < 0 then -1 else 1,
		theta = if look.X < 0 then math.pi else 0,
		oneShot = nil,
		oneShotAt = 0,
		oneShotAirborne = false,
		priority = 0,
		flash = 0,
		airborne = false,
		moving = false,
		fastest = 0,
		idleSince = os.clock(),
		nextGlance = os.clock() + 6 + math.random() * 5,
		lookRefresh = 0,
		dead = false,
	}
	entries[character] = entry
	if isLocal then
		localEntry = entry
	end
	rig:play("idle", 0)
	rig.onEvent = function(name: string)
		if name == "thud" and entry.isLocal then
			local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				Fx.puff(r.Position - Vector3.new(0, 2.6, 0) + entry.facing * 2, Color3.fromRGB(170, 160, 150), 2.2, 0.35)
			end
		end
	end
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			rig:destroy()
			entries[character] = nil
			if localEntry == entry then
				localEntry = nil
			end
		end
	end)
	-- Other players' actions arrive as character attributes.
	character:GetAttributeChangedSignal("SwingAt"):Connect(function()
		if not entry.isLocal then
			local clip = SWING_CLIPS[character:GetAttribute("Swing") or "side"]
			if clip then
				play(entry, clip)
			end
		end
	end)
	character:GetAttributeChangedSignal("HurtAt"):Connect(function()
		play(entry, "hurt")
		entry.flash = 1
	end)
	character:GetAttributeChangedSignal("Dead"):Connect(function()
		if character:GetAttribute("Dead") and not entry.dead then
			play(entry, "death")
			entry.dead = true
			-- Defeat: the light goes out in a spray of dark shards and a pale ring.
			local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local at = r.Position
				Fx.shatter(at, Color3.fromRGB(26, 24, 34), 16, 1.3)
				Fx.ring(at - Vector3.new(0, 2.6, 0), Color3.fromRGB(230, 230, 245), 10, 0.9, 0.4)
				task.delay(1.1, function()
					Fx.glitter(at, Color3.fromRGB(220, 225, 255), 26, 2)
				end)
			end
		elseif not character:GetAttribute("Dead") then
			entry.dead = false
		end
	end)
end

-- ===== Choosing clips =====

local function locomotion(entry: Entry, root: BasePart, grounded: boolean, speed: number, vy: number): (string, number)
	if entry.isLocal then
		local action = State.action
		if action == "dash" then
			return "dash", 1
		elseif action == "dodge" then
			return "dodge", 1
		elseif action == "wall" then
			return "wall", 1
		elseif action == "swing" then
			return "swing", 1
		elseif action == "push" then
			return "push", 1
		elseif action == "dive" then
			return "dive", 1
		elseif action == "cdash" then
			return "dash", 1.2
		elseif action == "heal" then
			return "heal", 1
		elseif State.charging then
			return "charge", 1
		elseif State.freezes.charms then
			return "sit", 1
		end
	end
	if not grounded then
		if vy > 10 then
			return "rise", 1
		elseif vy < -10 then
			return "fall", 1
		end
		return "apex", 1
	end
	if speed > 1.5 then
		-- Match the cycle to ground speed so feet stay planted.
		return "run", math.clamp(speed / 22, 0.45, 1.5)
	end
	return "idle", 1
end

-- Soft one-shots stop as soon as they no longer fit what the character is doing.
local function shouldCancel(entry: Entry, grounded: boolean, speed: number, now: number): boolean
	local clip = entry.oneShot
	if not clip or entry.priority > 1 then
		return false
	end
	if clip == "idleLook" then
		return speed > 1.5 or not grounded or (entry.isLocal and State.action ~= nil)
	elseif clip == "runStop" then
		return speed > 6 or not grounded
	elseif clip == "runStart" or clip == "turn" then
		return not grounded
	elseif clip == "land" then
		-- Let a running landing blend straight into the stride.
		return (speed > 8 and now - entry.oneShotAt > 0.08) or (not grounded and not entry.oneShotAirborne)
	elseif clip == "jumpStart" then
		return grounded and now - entry.oneShotAt > 0.15
	end
	return false
end

function Characters.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "CharacterRigs"
	fxFolder.Parent = workspace

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(build, character)
		end)
		if player.Character then
			task.defer(build, player.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local frozen = now < hitStopUntil
		if now - poiRefreshedAt > 5 then
			poiRefreshedAt = now
			refreshPoi()
		end
		for character, entry in entries do
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local rig = entry.rig
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local grounded = if entry.isLocal then State.grounded else (humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air)

			-- Facing eases around (a quick sweep rather than a snap); a reversal while on the
			-- ground plays the turn.
			local want = flat(root.CFrame.LookVector)
			local sign = if want.X < -0.2 then -1 elseif want.X > 0.2 then 1 else entry.facingSign
			if sign ~= entry.facingSign then
				entry.facingSign = sign
				if grounded and not entry.oneShot and not entry.dead then
					play(entry, "turn")
				end
			end
			-- Turning sweeps the face past the camera (angle 0 = right, pi = left, pi/2 = toward us).
			local thetaWant = if entry.facingSign > 0 then 0 else math.pi
			entry.theta += (thetaWant - entry.theta) * (1 - math.exp(-dt * 14))
			entry.facing = Vector3.new(math.cos(entry.theta), 0, math.sin(entry.theta))

			-- Take-off, landing and run start / stop transitions, for everyone.
			local airborne = not grounded
			if entry.airborne and not airborne then
				if not entry.isLocal then
					play(entry, "land")
				end
			elseif not entry.airborne and airborne and v.Y > 5 and not entry.isLocal then
				play(entry, "jumpStart")
			end
			entry.airborne = airborne
			local moving = speed > 4
			if grounded and not entry.dead then
				if moving and not entry.moving then
					play(entry, "runStart")
				elseif not moving and entry.moving and entry.fastest > 12 and speed < 1.5 then
					play(entry, "runStop")
				end
			end
			if moving then
				entry.fastest = math.max(entry.fastest * 0.98, speed)
			else
				entry.fastest *= 0.9
			end
			entry.moving = moving

			if entry.oneShot and shouldCancel(entry, grounded, speed, now) then
				entry.oneShot = nil
				entry.priority = 0
			end
			if entry.oneShot and rig:finished() and entry.oneShot ~= "death" then
				entry.oneShot = nil
				entry.priority = 0
			end

			local clip, clipSpeed = locomotion(entry, root, grounded, speed, v.Y)
			-- Ability states (dash, swing, heal...) take over from soft transitions.
			if entry.oneShot and entry.priority <= 1 and clip ~= "idle" and clip ~= "run" and clip ~= "rise" and clip ~= "fall" and clip ~= "apex" then
				entry.oneShot = nil
				entry.priority = 0
			end
			if not entry.oneShot and not entry.dead then
				-- Standing around for a while: an occasional glance about.
				if clip == "idle" then
					if now >= entry.nextGlance then
						entry.nextGlance = now + 7 + math.random() * 6
						play(entry, "idleLook")
					end
				else
					entry.nextGlance = math.max(entry.nextGlance, now + 5)
				end
				if not entry.oneShot then
					local fade = if clip == "run" or clip == "idle" then 0.16 elseif clip == "apex" then 0.18 else 0.1
					rig:play(clip, fade, clipSpeed)
				end
			end

			-- Head tracking toward nearby points of interest.
			if now >= entry.lookRefresh then
				entry.lookRefresh = now + 0.25
				rig.lookTarget = if entry.oneShot == nil or entry.priority < 3 then lookTargetFor(root, entry.facingSign) else nil
			end

			-- Hurt flash and post-hit flicker.
			entry.flash = math.max(0, entry.flash - dt * 5)
			rig:tint(Color3.fromRGB(255, 255, 255), entry.flash)
			if entry.isLocal then
				local flicker = now < State.invulnUntil and math.floor(now * 14) % 2 == 0
				rig:setTransparency(if flicker then 0.55 else 0)
			end

			local pos = root.Position - Vector3.new(0, 3, 0)
			rig:update(if frozen and entry.isLocal then 0 else dt, Rig.frame(pos, entry.facing))
		end
	end)
end

return Characters
