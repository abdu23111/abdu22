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
	local solids = { workspace.Terrain }
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
					if handler.onHit(player, damage, knock, kind) then
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

	Net.event("Attack").OnServerEvent:Connect(function(player: Player, direction: unknown, aim: unknown, stage: unknown)
		local art = direction == "cleave" or direction == "dashslash" or direction == "cyclone"
		if direction ~= "side" and direction ~= "up" and direction ~= "down" and not art then
			return
		end
		-- Nail arts (Great Slash, Dash Slash, Cyclone Slash) all come with the Cleaving Arc.
		if art and not player:GetAttribute("HasCleave") then
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
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		-- The client auto-aims toward nearby targets and sends that heading; accept it as long
		-- as it's roughly where the character is facing (the turn may not have replicated yet).
		local swingFrame = root.CFrame
		if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 then
			local a = Vector3.new(aim.X, 0, aim.Z)
			if a.Magnitude > 0.5 and a.Unit:Dot(look) > -0.2 then
				look = a.Unit
				swingFrame = CFrame.lookAt(root.Position, root.Position + look)
			end
		end
		local reach = if PlayerService.hasCharm(player, "long_reach") then 1.35 else 1
		-- Side swings chain into a three-hit combo; the third is a heavier, longer finisher.
		local comboStage = if direction == "side" and (stage == 2 or stage == 3) then stage :: number else 1
		if comboStage == 3 then
			reach *= 1.25
		end
		local boxCFrame, size = Hitbox.nail(swingFrame, direction :: string, reach)
		-- A little extra room to forgive network latency.
		size += Vector3.new(1.5, 1.5, 1.5)
		local character = player.Character
		if character then
			-- Lets every client animate this player's swing.
			character:SetAttribute("Swing", if comboStage == 2 then "side2" elseif comboStage == 3 then "finish" else direction)
			character:SetAttribute("SwingAt", now)
		end

		local damage = nailDamage(player)
		local kind = "nail"
		if direction == "cleave" then
			damage = math.floor(damage * Config.CLEAVE_MULT + 0.5)
			kind = "cleave"
		elseif direction == "dashslash" then
			damage = math.floor(damage * Config.DASH_SLASH_MULT + 0.5)
			kind = "cleave"
		elseif direction == "cyclone" then
			damage = math.max(1, math.floor(damage * Config.CYCLONE_MULT + 0.5))
			kind = "cleave"
		elseif comboStage == 3 then
			damage = math.floor(damage * 1.6 + 0.5)
			kind = "finish"
		end
		local knock = if direction == "up" then Vector3.new(0, 1, 0) elseif direction == "down" then Vector3.new(0, -1, 0) else look
		local function resolve()
			local parts = workspace:GetPartBoundsInBox(boxCFrame, size, params)
			if strike(player, parts, damage, knock, kind, {}) then
				PlayerService.addSoul(player, Config.SOUL_PER_HIT)
			end
		end
		if direction == "cyclone" then
			-- A spinning flurry: several hits around the body as it turns.
			task.spawn(function()
				for i = 1, Config.CYCLONE_HITS do
					local r = PlayerService.rootOf(player)
					if not r or (player:GetAttribute("Masks") or 0) <= 0 then
						return
					end
					boxCFrame, size = Hitbox.nail(CFrame.lookAt(r.Position, r.Position + look), "cyclone", reach)
					size += Vector3.new(1.5, 1.5, 1.5)
					local parts = workspace:GetPartBoundsInBox(boxCFrame, size, params)
					if strike(player, parts, damage, if i % 2 == 0 then look else -look, kind, {}) and i == 1 then
						PlayerService.addSoul(player, Config.SOUL_PER_HIT)
					end
					task.wait(0.13)
				end
			end)
		elseif comboStage == 3 then
			-- The finisher lands on its contact frame, after the wind-up (matching the client).
			task.delay(0.12, function()
				local r = PlayerService.rootOf(player)
				if r and (player:GetAttribute("Masks") or 0) > 0 then
					boxCFrame, size = Hitbox.nail(CFrame.lookAt(r.Position, r.Position + look), "side", reach)
					size += Vector3.new(1.5, 1.5, 1.5)
					resolve()
				end
			end)
		else
			resolve()
		end
	end)

	-- ===== Lumen Bolt =====

	-- Soul spells: a scream that bursts above you, and a dive that explodes where you land.
	local lastSpell: { [Player]: number } = {}
	Net.event("Spell").OnServerEvent:Connect(function(player: Player, kind: unknown)
		if kind ~= "shriek" and kind ~= "dive" then
			return
		end
		local now = os.clock()
		if lastSpell[player] and now - lastSpell[player] < 0.4 then
			return
		end
		local root = PlayerService.rootOf(player)
		local soul = (player:GetAttribute("Soul") or 0) :: number
		if not root or soul < Config.BOLT_COST or (player:GetAttribute("Masks") or 0) <= 0 then
			return
		end
		lastSpell[player] = now
		player:SetAttribute("Soul", soul - Config.BOLT_COST)
		local box, size, knock
		if kind == "shriek" then
			box, size, knock = CFrame.new(root.Position + Vector3.new(0, 8, 0)), Vector3.new(14, 13, 10), Vector3.new(0, 1, 0)
		else
			box, size, knock = CFrame.new(root.Position + Vector3.new(0, -1, 0)), Vector3.new(18, 8, 10), Vector3.new(0, 1, 0)
		end
		local damage = math.floor(nailDamage(player) * (if kind == "dive" then 2.6 else 2.2) + 0.5)
		strike(player, workspace:GetPartBoundsInBox(box, size, params), damage, knock, "spell", {})
		PlayerService.invulnerable(player, if kind == "dive" then 0.5 else 0.2)
	end)

	Net.event("Bolt").OnServerEvent:Connect(function(player: Player, aim: unknown)
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
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		-- Aim toward the client's lock-on target if it's roughly in front of the player.
		local dir = look
		if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 then
			local a = aim.Unit
			if a:Dot(look) > 0.4 then
				dir = a
			end
		end
		local spur = PlayerService.hasCharm(player, "glass_spur")
		local start = root.Position + dir * 2 + Vector3.new(0, 0.4, 0)
		local character = player.Character
		if character then
			character:SetAttribute("Swing", "bolt")
			character:SetAttribute("SwingAt", now)
		end
		local part = Props.make("Part", {
			Name = "LumenBolt",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 4),
			CFrame = CFrame.lookAt(start, start + dir),
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
			velocity = dir * Config.BOLT_SPEED,
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
			bolt.part.CFrame = CFrame.lookAt(bolt.position, bolt.position + bolt.velocity)
			local parts = workspace:GetPartBoundsInBox(CFrame.lookAt(bolt.position, bolt.position + bolt.velocity), Vector3.new(3.5, 3.5, 4), params)
			strike(bolt.player, parts, bolt.damage, bolt.velocity.Unit, "bolt", bolt.struck)
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
				local away = part.Position - root.Position
				handler.onHit(player, 10, Vector3.new(away.X, 0, away.Z).Unit)
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
