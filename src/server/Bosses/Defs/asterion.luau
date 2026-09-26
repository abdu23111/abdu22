-- Asterion, the Moth Seraph: keeper of the Great Lamp, who dimmed it out of mercy.
-- Three phases: radiant bursts and dives, then denser patterns, then everything at once.

local MASK = Color3.fromRGB(232, 228, 218)
local GOLD = Color3.fromRGB(255, 220, 150)
local PALE = Color3.fromRGB(250, 240, 215)

return {
	name = "Asterion",
	title = "The Moth Seraph",
	hp = 340,
	size = Vector3.new(7, 7, 4),
	flying = true,
	phases = { 0.66, 0.33 },
	geo = 400,
	final = true,
	music = "boss_final",
	parts = {
		{ size = Vector3.new(6, 5.6, 0.2), offset = Vector3.new(-3.3, 1, -0.6), rz = 0.25, color = PALE, transparency = 0.1, flap = 0.35 },
		{ size = Vector3.new(6, 5.6, 0.2), offset = Vector3.new(3.3, 1, -0.6), rz = -0.25, color = PALE, transparency = 0.1, flap = -0.35 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(1.4, 1.4, 0.3), offset = Vector3.new(-3.6, 1.6, -0.4), color = Color3.fromRGB(255, 200, 120), neon = true, flap = 0.35 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(1.4, 1.4, 0.3), offset = Vector3.new(3.6, 1.6, -0.4), color = Color3.fromRGB(255, 200, 120), neon = true, flap = -0.35 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.6, 5, 2.4), offset = Vector3.new(0, 0, 0), color = Color3.fromRGB(228, 220, 198) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.4, 3.4, 0.2), offset = Vector3.new(0, 3.4, -0.9), color = GOLD, neon = true, transparency = 0.35 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2.4, 2.2), offset = Vector3.new(0, 3.3, 0.2), color = MASK },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.7, 0.3), offset = Vector3.new(0.5, 3.4, 1.2), color = Color3.fromRGB(255, 210, 120), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.7, 0.3), offset = Vector3.new(-0.5, 3.4, 1.2), color = Color3.fromRGB(255, 210, 120), neon = true },
		{ size = Vector3.new(0.2, 1.8, 0.2), offset = Vector3.new(0.5, 5, 0), rz = -0.5, color = MASK },
		{ size = Vector3.new(0.2, 1.8, 0.2), offset = Vector3.new(-0.5, 5, 0), rz = 0.5, color = MASK },
	},
	run = function(b)
		local function burst(n: number, speed: number, offset: number)
			for i = 1, n do
				local a = offset + (i / n) * math.pi * 2
				b.projectile(b.position, Vector3.new(math.cos(a), math.sin(a), 0) * speed, { color = GOLD, radius = 0.9, lifetime = 5, passWalls = true })
			end
		end
		local function featherRain(count: number)
			local xs = {}
			for _ = 1, count do
				table.insert(xs, b.randomX())
			end
			for _, x in xs do
				b.marker(x, 1.6, 0.5)
			end
			b.wait(0.5)
			for _, x in xs do
				b.projectile(Vector3.new(x, b.ceilY - 1, 0), Vector3.new(b.rng:NextNumber(-2, 2), -28, 0), { color = PALE, radius = 0.7, lifetime = 3, passWalls = true })
				b.wait(0.08)
			end
		end
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				b.moveTo(b.randomX(), b.ceilY - b.rng:NextNumber(6, 10), 28)
				b.telegraph(0.5)
				local n = ({ 9, 12, 14 })[b.phase]
				local offset = b.rng:NextNumber(0, math.pi)
				burst(n, 17, offset)
				if b.phase >= 2 then
					b.wait(0.45)
					burst(n, 14, offset + math.pi / n)
				end
				b.wait(b.pace(0.8))
			elseif roll == 2 then
				-- Telegraphed dive through the player's position.
				for _ = 1, if b.phase >= 3 then 2 else 1 do
					local target = b.targetPos()
					b.faceTarget()
					b.line(b.position, target, 0.6)
					local dir = (target - b.position).Unit
					local finish = b.position + dir * ((target - b.position).Magnitude + 10)
					b.moveTo(b.clampX(finish.X), math.max(finish.Y, b.floorY + b.size.Y / 2), 72)
					b.shake(0.4)
					if b.phase >= 3 then
						burst(8, 14, 0)
					end
					b.wait(0.2)
					b.moveTo(b.clampX(b.position.X), b.ceilY - 8, 30)
				end
				b.wait(b.pace(0.5))
			else
				b.telegraph(0.4)
				featherRain(({ 8, 12, 16 })[b.phase])
				b.wait(b.pace(0.6))
			end
		end
	end,
}
