-- Draws every player as the animated Wanderer rig. The local player's animation follows the
-- movement and combat state directly; other players are animated from their velocity and
-- the attributes the server sets on their character (Swing, HurtAt, HealAt, Dead).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.Rig)
local State = require(script.Parent.State)

local localPlayer = Players.LocalPlayer

local Characters = {}

type Entry = {
	rig: any,
	character: Model,
	isLocal: boolean,
	facing: Vector3,
	oneShot: string?,
	priority: number,
	flash: number,
	lastSwingAt: number,
	lastHurtAt: number,
	lastHealAt: number,
	airborne: boolean,
}

local entries: { [Model]: Entry } = {}
local localEntry: Entry? = nil
local hitStopUntil = 0
local fxFolder: Folder

local SWING_CLIPS = { side = "attackSide", up = "attackUp", down = "attackDown", cleave = "cleave", bolt = "bolt" }
-- Higher priority one-shots can interrupt lower ones.
local PRIORITY = { death = 5, hurt = 4, cleave = 3, attackSide = 3, attackUp = 3, attackDown = 3, bolt = 3, flip = 2, dodge = 2, land = 1, jumpStart = 1 }

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.xAxis
end

local function play(entry: Entry, clip: string)
	local p = PRIORITY[clip] or 1
	if entry.oneShot and not entry.rig:finished() and p < entry.priority then
		return
	end
	entry.oneShot = clip
	entry.priority = p
	entry.rig:play(clip, if p >= 3 then 0.04 else 0.08, 1, true)
end

-- One-shot actions for the local player (called by combat and movement).
function Characters.action(clip: string)
	if localEntry then
		play(localEntry, clip)
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

local function build(character: Model)
	if entries[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local isLocal = character == localPlayer.Character
	local rig = Rig.new("wanderer", fxFolder)
	-- The lantern at the hip lights the way (and casts shadows for your own character).
	for _, part in rig:partsWithTag("glow") do
		if part.Material == Enum.Material.Neon and part.Color.R > part.Color.B then
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.1
			light.Color = Color3.fromRGB(255, 214, 160)
			light.Shadows = isLocal
			light.Parent = part
			break
		end
	end
	local entry: Entry = {
		rig = rig,
		character = character,
		isLocal = isLocal,
		facing = flat((root :: BasePart).CFrame.LookVector),
		oneShot = nil,
		priority = 0,
		flash = 0,
		lastSwingAt = 0,
		lastHurtAt = 0,
		lastHealAt = 0,
		airborne = false,
	}
	entries[character] = entry
	if isLocal then
		localEntry = entry
	end
	rig:play("idle", 0)
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
		if character:GetAttribute("Dead") then
			play(entry, "death")
		end
	end)
end

local function locomotion(entry: Entry, root: BasePart): (string, number)
	local character = entry.character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	if entry.isLocal then
		local action = State.action
		if action == "dash" then
			return "dash", 1
		elseif action == "dodge" then
			return "dodge", 1
		elseif action == "wall" then
			return "wall", 1
		elseif action == "heal" then
			return "heal", 1
		elseif State.charging then
			return "charge", 1
		elseif State.freezes.charms then
			return "sit", 1
		end
		grounded = State.grounded
	end
	if not grounded then
		return if v.Y > 4 then "rise" else "fall", 1
	end
	if speed > 1.5 then
		return "run", math.clamp(speed / 22, 0.5, 1.4)
	end
	return "idle", 1
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
		for character, entry in entries do
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			-- Ease the facing so turns sweep instead of snapping.
			local want = flat(root.CFrame.LookVector)
			entry.facing = flat(entry.facing:Lerp(want, 1 - math.exp(-dt * 18)))

			local rig = entry.rig
			if entry.oneShot and rig:finished() and entry.oneShot ~= "death" then
				entry.oneShot = nil
				entry.priority = 0
			end
			if not entry.oneShot then
				local clip, speed = locomotion(entry, root)
				-- Anticipation and landing squash for remote players (local ones come from Movement).
				if not entry.isLocal then
					local airborne = clip == "rise" or clip == "fall"
					if entry.airborne and not airborne then
						play(entry, "land")
						clip = "land"
					end
					entry.airborne = airborne
				end
				if not entry.oneShot then
					rig:play(clip, if clip == "run" or clip == "idle" then 0.15 else 0.1, speed)
				end
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
