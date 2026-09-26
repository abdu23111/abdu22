-- Asterion, the Moth Seraph: keeper of the Great Lamp, who dimmed it out of mercy.
-- Radiant bursts, telegraphed dives, and rains of burning feathers.
-- Three phases: each adds density and speed, and in the last every dive ends in a burst.

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
	run = function(b)
		local function burst(n: number, speed: number, offset: number, tilt: number)
			for i = 1, n do
				local a = offset + (i / n) * math.pi * 2
				local v = Vector3.new(math.cos(a) * math.cos(tilt), math.sin(tilt), math.sin(a) * math.cos(tilt)) * speed
				b.projectile(b.position, v, { color = GOLD, radius = 0.9, lifetime = 5, passWalls = true, quiet = i > 1 })
			end
		end
		local function featherRain(count: number)
			local spots = {}
			for _ = 1, count do
				local t = b.targetGround()
				local p = b.clamp(t + Vector3.new(b.rng:NextNumber(-12, 12), 0, b.rng:NextNumber(-12, 12)))
				table.insert(spots, p)
				b.marker(p, 1.6, 0.55)
			end
			b.wait(0.55)
			for _, p in spots do
				b.projectile(Vector3.new(p.X, b.ceilY - 1, p.Z), Vector3.new(0, -30, 0), { color = PALE, radius = 0.7, lifetime = 3, passWalls = true, quiet = true })
				b.wait(0.06)
			end
		end
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				local p = b.randomPoint(b.ceilY - b.rng:NextNumber(6, 10))
				b.moveTo(p, 28, "move")
				b.faceTarget()
				b.telegraph(0.5)
				local n = ({ 10, 12, 14 })[b.phase]
				local offset = b.rng:NextNumber(0, math.pi)
				burst(n, 17, offset, -0.15)
				if b.phase >= 2 then
					b.wait(0.45)
					burst(n, 14, offset + math.pi / n, -0.35)
				end
				b.rest(0.8)
			elseif roll == 2 then
				-- Telegraphed dive through where the player stands.
				for _ = 1, if b.phase >= 3 then 2 else 1 do
					local target = b.targetPos()
					b.faceTarget()
					b.line(b.position, target, 0.6)
					local dir = (target - b.position).Unit
					local finish = target + dir * 10
					b.moveTo(Vector3.new(finish.X, math.max(finish.Y, b.floorY + b.size.Y / 2), finish.Z), 72, "attack")
					b.shake(0.5)
					if b.phase >= 3 then
						burst(8, 14, 0, 0.1)
					end
					b.wait(0.2)
					b.moveTo(Vector3.new(b.position.X, b.ceilY - 8, b.position.Z), 30, "move")
				end
				b.rest(0.5)
			else
				b.telegraph(0.4)
				featherRain(({ 9, 13, 17 })[b.phase])
				b.rest(0.6)
			end
		end
	end,
}
