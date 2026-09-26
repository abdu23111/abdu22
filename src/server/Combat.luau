-- Server-side combat. The client plays effects instantly; the server decides what was hit.
-- Handles nail strikes (side / up / down / the charged Cleaving Arc), the Lumen Bolt spell,
-- breakable walls, crystal seals, levers and sigils, and the Kindled Spirit healing burst.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Hitbox = require(Shared.Hitbox)
local Damageable = require(script.Parent.Damageable)
local Enemies = require(script.Parent.Enemies)
local Props = require(script.Parent.World.Props)

local Combat = {}

type Bolt = {
	player: Player,
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	travelled: number,
	range: number,
	damage: number,
	struck: { [Instance]: boolean },
}

function Combat.init(infos, PlayerService)
	local lastSwing: { [Player]: number } = {}
	local lastBolt: { [Player]: number } = {}
	local warnedSeal: { [Player]: boolean } = {}
	local bolts: { Bolt } = {}

	local include = { workspace:WaitForChild("Enemies"), workspace:WaitForChild("Echoes") }
	local solids = {}
	for _, info in infos do
		table.insert(include, info.folder:FindFirstChild("Breakables"))
		table.insert(include, info.folder:FindFirstChild("Switches"))
		table.insert(solids, info.folder:FindFirstChild("Map"))
		table.insert(solids, info.folder:FindFirstChild("Breakables"))
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include
	wallParams.FilterDescendantsInstances = solids

	local function breakPart(player: Player, part: BasePart)
		Enemies.burst(part.Position, Color3.fromRGB(255, 255, 255), 30)
		Enemies.burst(part.Position, part.Color, 20)
		part:Destroy()
		PlayerService.notify(player, "A hidden passage...", nil, "secret")
	end

	-- Apply one strike to everything overlapping a box. `kind` is "nail", "cleave" or "bolt".
	-- Returns true if anything living was hit (for Soul).
	local function strike(player: Player, parts: { BasePart }, damage: number, knock: Vector3, kind: string, struck: { [Instance]: boolean }): boolean
		local soul = false
		for _, part in parts do
			if struck[part] then
				continue
			end
			if part.Name == "CrackedWall" then
				struck[part] = true
				if kind == "bolt" then
					continue
				end
				local hp = ((part:GetAttribute("HP") or 1) :: number) - (if kind == "cleave" then 3 else 1)
				part:SetAttribute("HP", hp)
				Enemies.burst(part.Position, part.Color, 10)
				if hp <= 0 then
					breakPart(player, part)
				end
			elseif part.Name == "CrystalSeal" then
				struck[part] = true
				if kind == "cleave" then
					breakPart(player, part)
				elseif not warnedSeal[player] then
					warnedSeal[player] = true
					PlayerService.notify(player, "The crystal rings, unbroken.", "Only a heavier, charged blow could shatter it.", "info")
				end
			elseif part.Name == "Switch" then
				struck[part] = true
				local switchKind = part:GetAttribute("Kind")
				if switchKind == "lever" or (switchKind == "sigil" and kind == "bolt") then
					PlayerService.openSwitch(player, part:GetAttribute("Zone") :: string)
				elseif switchKind == "sigil" and not warnedSeal[player] then
					warnedSeal[player] = true
					PlayerService.notify(player, "The sigil sleeps.", "It seems to be waiting for light, not steel.", "info")
				end
			else
				local target, handler = Damageable.find(part)
				if target and handler and not struck[target] then
					struck[target] = true
					if handler.onHit(player, damage, knock) then
						soul = true
					end
				end
			end
		end
		return soul
	end

	local function nailDamage(player: Player): number
		local level = (player:GetAttribute("NailLevel") or 1) :: number
		local damage = Config.NAIL_DAMAGE[level] or Config.NAIL_DAMAGE[1]
		if PlayerService.hasCharm(player, "ember_edge") then
			damage = math.floor(damage * 1.4 + 0.5)
		end
		return damage
	end

	Net.event("Attack").OnServerEvent:Connect(function(player: Player, direction: unknown)
		if direction ~= "side" and direction ~= "up" and direction ~= "down" and direction ~= "cleave" then
			return
		end
		if direction == "cleave" and not player:GetAttribute("HasCleave") then
			return
		end
		local now = os.clock()
		if lastSwing[player] and now - lastSwing[player] < Config.ATTACK_COOLDOWN * 0.6 then
			return
		end
		lastSwing[player] = now
		local root = PlayerService.rootOf(player)
		if not root or (player:GetAttribute("Masks") or 0) <= 0 then
			return
		end
		local facing = if root.CFrame.LookVector.X >= 0 then 1 else -1
		local reach = if PlayerService.hasCharm(player, "long_reach") then 1.35 else 1
		local center, size = Hitbox.nail(root.Position, facing, direction :: string, reach)
		-- A little extra room to forgive network latency.
		size += Vector3.new(1.5, 1.5, 0)

		local damage = nailDamage(player)
		local kind = "nail"
		if direction == "cleave" then
			damage = math.floor(damage * Config.CLEAVE_MULT + 0.5)
			kind = "cleave"
		end
		local knock = if direction == "up" then Vector3.new(0, 1, 0) elseif direction == "down" then Vector3.new(0, -1, 0) else Vector3.new(facing, 0, 0)
		local parts = workspace:GetPartBoundsInBox(CFrame.new(center), size, params)
		if strike(player, parts, damage, knock, kind, {}) then
			PlayerService.addSoul(player, Config.SOUL_PER_HIT)
		end
	end)

	-- ===== Lumen Bolt =====

	Net.event("Bolt").OnServerEvent:Connect(function(player: Player)
		if not player:GetAttribute("HasBolt") then
			return
		end
		local now = os.clock()
		if lastBolt[player] and now - lastBolt[player] < 0.35 then
			return
		end
		local soul = (player:GetAttribute("Soul") or 0) :: number
		local root = PlayerService.rootOf(player)
		if soul < Config.BOLT_COST or not root or (player:GetAttribute("Masks") or 0) <= 0 then
			return
		end
		lastBolt[player] = now
		player:SetAttribute("Soul", soul - Config.BOLT_COST)
		local facing = if root.CFrame.LookVector.X >= 0 then 1 else -1
		local spur = PlayerService.hasCharm(player, "glass_spur")
		local start = root.Position + Vector3.new(facing * 2, 0.4, 0)
		local part = Props.make("Part", {
			Name = "LumenBolt",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 1.8, 1.8),
			Position = start,
			Color = Color3.fromRGB(235, 245, 255),
			Material = Enum.Material.Neon,
			Parent = workspace,
		})
		Props.make("PointLight", { Range = 18, Brightness = 2.5, Color = Color3.fromRGB(200, 230, 255), Parent = part })
		Props.make("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(210, 235, 255)),
			LightEmission = 1,
			Size = NumberSequence.new(0.6, 0),
			Lifetime = NumberRange.new(0.2, 0.4),
			Rate = 80,
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Parent = part,
		})
		table.insert(bolts, {
			player = player,
			part = part,
			position = start,
			velocity = Vector3.new(facing * Config.BOLT_SPEED, 0, 0),
			travelled = 0,
			range = Config.BOLT_RANGE * (if spur then 1.3 else 1),
			damage = math.floor(Config.BOLT_DAMAGE * (if spur then 1.5 else 1)),
			struck = {},
		})
	end)

	RunService.Heartbeat:Connect(function(dt)
		for i = #bolts, 1, -1 do
			local bolt = bolts[i]
			local step = bolt.velocity * dt
			local hitWall = workspace:Raycast(bolt.position, step, wallParams)
			bolt.position += step
			bolt.travelled += step.Magnitude
			bolt.part.Position = bolt.position
			local parts = workspace:GetPartBoundsInBox(CFrame.new(bolt.position), Vector3.new(3.5, 3, 8), params)
			strike(bolt.player, parts, bolt.damage, Vector3.new(math.sign(bolt.velocity.X), 0, 0), "bolt", bolt.struck)
			if hitWall or bolt.travelled >= bolt.range or not bolt.player.Parent then
				Enemies.burst(bolt.position, Color3.fromRGB(220, 240, 255), 18)
				bolt.part:Destroy()
				table.remove(bolts, i)
			end
		end
	end)

	-- ===== Kindled Spirit: healing releases a burst of light =====

	PlayerService.onHealBurst = function(player: Player)
		local root = PlayerService.rootOf(player)
		if not root then
			return
		end
		Enemies.burst(root.Position, Color3.fromRGB(255, 230, 170), 40)
		local parts = workspace:GetPartBoundsInBox(CFrame.new(root.Position), Vector3.new(16, 12, 10), params)
		local struck = {}
		for _, part in parts do
			local target, handler = Damageable.find(part)
			if target and handler and not struck[target] and target.Parent ~= workspace:FindFirstChild("Echoes") then
				struck[target] = true
				handler.onHit(player, 10, Vector3.new(math.sign(part.Position.X - root.Position.X), 0, 0))
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastBolt[player] = nil
		warnedSeal[player] = nil
	end)
end

return Combat
