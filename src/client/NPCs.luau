-- Brings the kingdom's residents to life: each NPC anchor the server places becomes an
-- animated rig that idles in its own way, follows you with its eyes, reacts when you come
-- close, turns to face you and gestures while you talk, then settles back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.Rig)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local NPCs = {}

type Entry = {
	id: string,
	anchor: BasePart,
	rig: any,
	feet: Vector3,
	restFacing: Vector3,
	facing: Vector3,
	noticed: boolean,
	mode: string,
	glance: Vector3?,
	nextGlance: number,
}

local entries: { [BasePart]: Entry } = {}
local rigFolder: Folder

local LOOK_RADIUS = 20
local NOTICE_RADIUS = 14
local RESET_RADIUS = 22
local CULL_DISTANCE = 180

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

local function onEvent(entry: Entry, name: string)
	if name == "spark" then
		-- Tock's hammer meets the anvil.
		local at = entry.feet + entry.facing * 1.3 + Vector3.new(0, 1.3, 0)
		Fx.sparks(at, Color3.fromRGB(255, 190, 110), 5, 0.9, Vector3.yAxis)
		Fx.light(at, Color3.fromRGB(255, 170, 90), 10, 2, 0.15)
	end
end

local function build(anchor: BasePart)
	if entries[anchor] then
		return
	end
	local id = anchor:GetAttribute("NpcId") :: string?
	if not id or not Rig.data(id) then
		return
	end
	local rig = Rig.new(id, rigFolder)
	local rest = flat((anchor:GetAttribute("Facing") or Vector3.xAxis) :: Vector3) or Vector3.xAxis
	local entry: Entry = {
		id = id,
		anchor = anchor,
		rig = rig,
		feet = anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0),
		restFacing = rest,
		facing = rest,
		noticed = false,
		mode = "idle",
		glance = nil,
		nextGlance = os.clock() + math.random() * 4,
	}
	entries[anchor] = entry
	rig.onEvent = function(name: string)
		onEvent(entry, name)
	end
	-- Lamps, candles and halos give off a little light of their own.
	local glow = rig:partsWithTag("flame")[1] or rig:partsWithTag("glow")[1]
	if glow then
		local l = Instance.new("PointLight")
		l.Range = 12
		l.Brightness = 0.9
		l.Color = glow.Color
		l.Parent = glow
	end
	-- Everyone starts at a different point in their idle so rooms don't move in lockstep.
	rig:play("idle", 0)
	rig.time = math.random() * 4
	anchor.AncestryChanged:Connect(function(_, parent)
		if not parent then
			entries[anchor] = nil
			rig:destroy()
		end
	end)
end

function NPCs.init()
	rigFolder = Instance.new("Folder")
	rigFolder.Name = "NPCRigs"
	rigFolder.Parent = workspace

	task.spawn(function()
		local world = workspace:WaitForChild("World")
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "NPCAnchor" then
				build(d)
			end
		end
		world.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and d.Name == "NPCAnchor" then
				task.defer(build, d)
			end
		end)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		local root = State.root
		for _, entry in entries do
			if (entry.feet - camPos).Magnitude > CULL_DISTANCE then
				continue
			end
			local rig = entry.rig
			local toPlayer = if root then root.Position - entry.feet else nil
			local distance = if toPlayer then Vector3.new(toPlayer.X, 0, toPlayer.Z).Magnitude else math.huge
			local talking = State.talkingTo == entry.id

			-- Reactions: talk while spoken to, a little start when you first come close.
			if talking then
				if entry.mode ~= "talk" then
					entry.mode = "talk"
					rig:play("talk", 0.2)
				end
			elseif entry.mode == "talk" then
				entry.mode = "idle"
				rig:play("idle", 0.3)
			elseif entry.mode == "notice" then
				if rig:finished() then
					entry.mode = "idle"
					rig:play("idle", 0.3)
				end
			elseif distance < NOTICE_RADIUS and not entry.noticed then
				entry.noticed = true
				entry.mode = "notice"
				rig:play("notice", 0.12, 1, true)
			end
			if distance > RESET_RADIUS then
				entry.noticed = false
			end

			-- Turn toward whoever they're talking to; drift back to their resting pose after.
			local wantFacing = entry.restFacing
			if toPlayer and (talking or (entry.mode == "notice" and distance < NOTICE_RADIUS)) then
				local f = flat(toPlayer)
				if f then
					-- Noticing is a half-turn; talking faces you properly.
					wantFacing = if talking then f else (entry.restFacing + f).Unit
				end
			end
			local blended = entry.facing:Lerp(wantFacing, 1 - math.exp(-dt * 4))
			if blended.Magnitude > 1e-3 then
				entry.facing = blended.Unit
			end

			if root and distance < LOOK_RADIUS then
				rig.lookTarget = root.Position + Vector3.new(0, 1.5, 0)
			else
				-- Alone, they look about: a spot to one side, then the other, then straight ahead.
				local now = os.clock()
				if now >= entry.nextGlance then
					entry.nextGlance = now + 2.5 + math.random() * 3.5
					local r = math.random()
					entry.glance = if r < 0.35 then nil else entry.feet + Vector3.new((math.random() - 0.5) * 24, 2 + math.random() * 4, 6)
				end
				rig.lookTarget = entry.glance
			end
			rig:update(dt, Rig.frame(entry.feet, entry.facing))
		end
	end)
end

return NPCs
