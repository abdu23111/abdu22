-- Server-side nail strikes. The client plays effects instantly; the server decides what was hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Hitbox = require(Shared.Hitbox)
local Damageable = require(script.Parent.Damageable)
local Enemies = require(script.Parent.Enemies)

local Combat = {}

function Combat.init(infos, PlayerService)
	local lastSwing: { [Player]: number } = {}
	local include = { workspace:WaitForChild("Enemies"), workspace:WaitForChild("Echoes") }
	for _, info in infos do
		table.insert(include, info.folder:FindFirstChild("Breakables"))
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include

	Net.event("Attack").OnServerEvent:Connect(function(player: Player, direction: unknown)
		if direction ~= "side" and direction ~= "up" and direction ~= "down" then
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

		local level = (player:GetAttribute("NailLevel") or 1) :: number
		local damage = Config.NAIL_DAMAGE[level] or Config.NAIL_DAMAGE[1]
		if PlayerService.hasCharm(player, "ember_edge") then
			damage = math.floor(damage * 1.4 + 0.5)
		end
		local knock = if direction == "up" then Vector3.new(0, 1, 0) elseif direction == "down" then Vector3.new(0, -1, 0) else Vector3.new(facing, 0, 0)

		local struck = {}
		local soul = false
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(center), size, params) do
			if part.Name == "CrackedWall" then
				if not struck[part] then
					struck[part] = true
					local hp = ((part:GetAttribute("HP") or 1) :: number) - 1
					part:SetAttribute("HP", hp)
					Enemies.burst(part.Position, part.Color, 10)
					if hp <= 0 then
						Enemies.burst(part.Position, Color3.fromRGB(255, 255, 255), 30)
						part:Destroy()
						PlayerService.notify(player, "A hidden passage...", nil, "secret")
					end
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
		if soul then
			PlayerService.addSoul(player, Config.SOUL_PER_HIT)
		end
	end)
end

return Combat
