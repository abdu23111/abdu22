-- Draws enemies, bosses and players' Echoes as animated rigs. The server only moves an
-- invisible hitbox and sets attributes on its model:
--   Rig     which rig to build           Anim / AnimAt  clip to play (AnimAt restarts it)
--   Anchor  hitbox centre -> rig feet    Warn           telegraph glow
--   HitAt   struck (flash + flinch)      Dead           defeated
-- Each client smooths the replicated motion, crossfades clips, turns heads toward the local
-- player, and turns clip events into effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.Rig)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local CameraController = require(script.Parent.CameraController)

local Creatures = {}

type Entry = {
	model: Model,
	hitbox: BasePart,
	rig: any,
	boss: boolean,
	anchor: number,
	pos: Vector3,
	facing: Vector3,
	speed: number,
	anim: string,
	oneShot: boolean,
	flash: number,
	warn: boolean,
	dead: boolean,
	color: Color3,
}

local entries: { [Model]: Entry } = {}
local rigFolder: Folder

local CULL_DISTANCE = 260
local WARN_COLOR = Color3.fromRGB(255, 196, 140)
local WHITE = Color3.fromRGB(255, 255, 255)

-- Clips a rig may lack, and what to play instead.
local FALLBACK = {
	shoot = { "attack", "windup" },
	slam = { "attack" },
	leap = { "move", "attack" },
	burrow = { "move" },
	vanish = { "idle" },
	stagger = { "hurt", "idle" },
	roar = { "windup", "idle" },
	death = { "hurt", "idle" },
	windup = { "idle" },
	attack = { "move", "idle" },
	move = { "idle" },
	hurt = { "idle" },
}

local function resolve(rig: any, anim: string): string
	if rig:has(anim) then
		return anim
	end
	for _, alt in FALLBACK[anim] or {} do
		if rig:has(alt) then
			return alt
		end
	end
	return "idle"
end

local function isLoop(rig: any, clip: string): boolean
	local c = rig.data.clips[clip]
	return c ~= nil and c.loop == true
end

-- The creature's main body colour, used for its shatter and dust.
local function mainColor(rig: any): Color3
	local best, bestVolume = WHITE, 0
	for _, entry in rig.parts do
		local z = entry.data.z
		local v = z[1] * z[2] * z[3]
		if entry.data.m ~= "n" and v > bestVolume then
			best, bestVolume = entry.color, v
		end
	end
	return best
end

local function playAnim(entry: Entry, anim: string, restart: boolean)
	local clip = resolve(entry.rig, anim)
	entry.anim = clip
	entry.oneShot = not isLoop(entry.rig, clip)
	entry.rig:play(clip, if entry.oneShot then 0.06 else 0.14, 1, restart)
end

local function nearLocal(at: Vector3, radius: number): boolean
	local root = State.root
	return root ~= nil and (root.Position - at).Magnitude < radius
end

-- Clip events -> effects, positioned from the creature's own pose.
local function onEvent(entry: Entry, name: string)
	local feet = entry.pos
	local f = entry.facing
	local size = entry.hitbox.Size
	local reach = math.max(size.X, size.Z)
	if name == "quake" then
		Fx.ring(feet, Color3.fromRGB(150, 140, 130), reach * 1.6, 0.6)
		Fx.puff(feet + f * reach * 0.5, Color3.fromRGB(120, 112, 108), reach * 0.6, 0.6)
		if nearLocal(feet, 60) then
			CameraController.shake(0.6)
		end
	elseif name == "roar" then
		Sfx.play("roar", 0.9)
		Fx.ring(feet + Vector3.new(0, size.Y * 0.6, 0), Color3.fromRGB(220, 220, 235), reach * 2.2, 0.7, 0.75)
		if nearLocal(feet, 80) then
			CameraController.shake(0.9)
		end
	elseif name == "radiance" then
		local at = feet + Vector3.new(0, size.Y * 0.6, 0)
		Fx.glitter(at, Color3.fromRGB(255, 225, 160), 40, reach)
		Fx.light(at, Color3.fromRGB(255, 220, 150), 40, 5, 0.6)
	elseif name == "beam" then
		Fx.light(feet + Vector3.new(0, size.Y * 0.6, 0) + f * 2, Color3.fromRGB(245, 170, 255), 30, 4, 0.5)
		Fx.glitter(feet + Vector3.new(0, size.Y * 0.6, 0) + f * 2, Color3.fromRGB(245, 170, 255), 18, 2)
	elseif name == "pages" then
		Fx.glitter(feet + Vector3.new(0, size.Y * 0.7, 0), Color3.fromRGB(236, 228, 200), 24, reach)
	elseif name == "splash" then
		Fx.ring(feet, Color3.fromRGB(30, 60, 66), reach * 1.8, 0.5, 0.3)
		Fx.sparks(feet + Vector3.new(0, 0.5, 0), Color3.fromRGB(60, 110, 120), 10, 1.4, Vector3.yAxis)
	elseif name == "thrust" then
		local tip = feet + Vector3.new(0, size.Y * 0.55, 0) + f * reach
		Fx.sparks(tip, Color3.fromRGB(255, 230, 190), 8, 2.4, f)
		Fx.slash(CFrame.lookAt(tip - f * 3, tip) * CFrame.Angles(0, 0, math.pi / 2), 3, false, Color3.fromRGB(255, 235, 200))
	elseif name == "slash" or name == "swing" then
		local pivot = feet + Vector3.new(0, size.Y * 0.5, 0)
		Fx.slash(CFrame.lookAt(pivot, pivot + f) * CFrame.Angles(0, 0, math.rad(-20)), reach * 0.9 + 1.5, name == "slash")
	elseif name == "cast" then
		Fx.glitter(feet + Vector3.new(0, size.Y * 0.5, 0) + f * 1.5, Color3.fromRGB(230, 225, 255), 14, 1.5)
	end
end

local function build(model: Model)
	if entries[model] or not model:GetAttribute("Rig") then
		return
	end
	local hitbox = (model.PrimaryPart or model:FindFirstChild("Hitbox") or model:FindFirstChild("Body")) :: any
	if not (hitbox and hitbox:IsA("BasePart")) then
		return
	end
	local rigName = model:GetAttribute("Rig") :: string
	if not Rig.data(rigName) then
		return
	end
	local rig = Rig.new(rigName, rigFolder)
	local anchor = (model:GetAttribute("Anchor") or 0) :: number
	local entry: Entry = {
		model = model,
		hitbox = hitbox,
		rig = rig,
		boss = model:GetAttribute("Boss") == true,
		anchor = anchor,
		pos = hitbox.Position - Vector3.new(0, anchor, 0),
		facing = hitbox.CFrame.XVector,
		speed = 0,
		anim = "idle",
		oneShot = false,
		flash = 0,
		warn = false,
		dead = false,
		color = mainColor(rig),
	}
	entries[model] = entry
	rig.onEvent = function(name: string)
		onEvent(entry, name)
	end
	-- Bosses and Echoes carry a faint light so they read in the dark.
	if entry.boss or rigName == "echo" then
		local glow = rig:partsWithTag("eye")[1] or rig:partsWithTag("glow")[1]
		if glow then
			local l = Instance.new("PointLight")
			l.Range = if entry.boss then 16 else 10
			l.Brightness = 0.8
			l.Color = glow.Color
			l.Parent = glow
		end
	end
	playAnim(entry, (model:GetAttribute("Anim") or "idle") :: string, true)

	model:GetAttributeChangedSignal("Anim"):Connect(function()
		local anim = (model:GetAttribute("Anim") or "idle") :: string
		playAnim(entry, anim, false)
		-- Lunges and slams kick up dust.
		if (anim == "attack" or anim == "slam") and not entry.dead and entry.anchor > 0 then
			Fx.puff(entry.pos + Vector3.new(0, 0.5, 0), entry.color:Lerp(Color3.fromRGB(170, 160, 150), 0.6), math.max(2, hitbox.Size.X * 0.6), 0.4)
		end
	end)
	model:GetAttributeChangedSignal("AnimAt"):Connect(function()
		playAnim(entry, (model:GetAttribute("Anim") or "idle") :: string, true)
	end)
	model:GetAttributeChangedSignal("Warn"):Connect(function()
		entry.warn = model:GetAttribute("Warn") == true
		-- Telegraph: a flare at the eyes and a warning ring on the ground, so every attack
		-- announces itself even out of the corner of your eye.
		if entry.warn and not entry.dead then
			local size = hitbox.Size
			local eye = entry.pos + Vector3.new(0, size.Y * 0.75, 0) + entry.facing * size.X * 0.4
			Fx.sparks(eye, WARN_COLOR, 6, 1, Vector3.yAxis)
			Fx.light(eye, WARN_COLOR, 12, 2, 0.35)
			Fx.ring(entry.pos, WARN_COLOR, math.max(size.X, size.Z) * (if entry.boss then 1.4 else 1.1), 0.45, 0.55)
		end
	end)
	model:GetAttributeChangedSignal("HitAt"):Connect(function()
		entry.flash = 1
		-- Small creatures flinch; bosses only flash so their attacks aren't interrupted.
		if not entry.boss and not entry.dead and rig:has("hurt") then
			entry.anim = "hurt"
			entry.oneShot = true
			rig:play("hurt", 0.03, 1, true)
		end
	end)
	model:GetAttributeChangedSignal("Dead"):Connect(function()
		if not model:GetAttribute("Dead") or entry.dead then
			return
		end
		entry.dead = true
		local center = entry.pos + Vector3.new(0, hitbox.Size.Y / 2, 0)
		if nearLocal(center, 70) then
			Sfx.play("shatter", if entry.boss then 0.7 else nil)
		end
		if entry.boss then
			Fx.shatter(center, entry.color, 30, 2.4)
			Fx.shatter(center, WHITE, 14, 1.6)
			Fx.ring(entry.pos, WHITE, 26, 1, 0.3)
		else
			Fx.shatter(center, entry.color, 12, math.clamp(hitbox.Size.Magnitude / 5, 0.8, 1.8))
			Fx.ring(entry.pos, entry.color:Lerp(WHITE, 0.4), 5, 0.4)
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		entries[model] = nil
		if entry.boss and entry.dead then
			-- Let the death pose linger, then dissolve into light.
			task.spawn(function()
				for i = 1, 20 do
					rig:setTransparency(i / 20)
					task.wait(0.06)
				end
				rig:destroy()
			end)
		else
			rig:destroy()
		end
	end)
end

local function watchFolder(folder: Instance)
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			-- Attributes and the hitbox arrive with the model, but give replication a frame.
			task.defer(build, child)
		end
	end)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			build(child)
		end
	end
end

function Creatures.init()
	rigFolder = Instance.new("Folder")
	rigFolder.Name = "CreatureRigs"
	rigFolder.Parent = workspace

	task.spawn(function()
		watchFolder(workspace:WaitForChild("Enemies"))
	end)
	task.spawn(function()
		watchFolder(workspace:WaitForChild("Echoes"))
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		local root = State.root
		local t = os.clock()
		for model, entry in entries do
			local hitbox = entry.hitbox
			local want = hitbox.Position - Vector3.new(0, entry.anchor, 0)
			local far = (want - camPos).Magnitude > CULL_DISTANCE
			if far then
				entry.pos = want
				continue
			end
			-- Smooth the replicated position (bosses dive fast, so they follow more tightly).
			local k = 1 - math.exp(-dt * (if entry.boss then 22 else 16))
			local before = entry.pos
			entry.pos = if (want - before).Magnitude > 25 then want else before:Lerp(want, k)
			local moved = Vector3.new(entry.pos.X - before.X, 0, entry.pos.Z - before.Z).Magnitude
			entry.speed += (moved / math.max(dt, 1e-3) - entry.speed) * math.min(1, dt * 8)

			local wantFacing = Vector3.new(hitbox.CFrame.XVector.X, 0, hitbox.CFrame.XVector.Z)
			if wantFacing.Magnitude > 1e-3 then
				local blended = entry.facing:Lerp(wantFacing.Unit, 1 - math.exp(-dt * 10))
				if blended.Magnitude > 1e-3 then
					entry.facing = blended.Unit
				end
			end

			local rig = entry.rig
			-- One-shots return to walking or idling once they finish (death holds its last pose).
			if entry.oneShot and rig:finished() and not entry.dead and entry.anim ~= "death" then
				local next = if entry.speed > 2 and rig:has("move") then "move" else "idle"
				entry.oneShot = false
				entry.anim = next
				rig:play(next, 0.15)
			elseif not entry.oneShot and not entry.dead then
				-- A walking creature that stops idles, and an idling one that moves walks.
				local serverAnim = model:GetAttribute("Anim")
				if serverAnim == "idle" or serverAnim == "move" then
					local next = if entry.speed > 2 and rig:has("move") then "move" else "idle"
					if next ~= entry.anim then
						entry.anim = next
						rig:play(next, 0.18)
					end
				end
			end

			-- Telegraph glow pulses; a strike flashes white.
			entry.flash = math.max(0, entry.flash - dt * 6)
			if entry.flash > 0.01 then
				rig:tint(WHITE, entry.flash)
			elseif entry.warn then
				rig:tint(WARN_COLOR, 0.35 + 0.25 * math.sin(t * 22))
			else
				rig:tint(nil, 0)
			end

			rig.lookTarget = if root and (root.Position - entry.pos).Magnitude < 40 then root.Position else nil
			rig:update(dt, Rig.frame(entry.pos, entry.facing))
		end
	end)
end

return Creatures
