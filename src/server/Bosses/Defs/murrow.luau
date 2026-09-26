-- Murrow, Archivist of Drowned Words: a scholar moth who stayed with the books.
-- Page volleys, blinks that end in a crashing slam, ink rain, and (from phase 2) the ink
-- tide that floods the floor. Phase 3 (one third): denser volleys and more rain.

local PAGE = Color3.fromRGB(236, 228, 200)
local INK = Color3.fromRGB(30, 60, 66)

return {
	name = "Murrow",
	title = "Archivist of Drowned Words",
	hp = 280,
	size = Vector3.new(5, 7, 4),
	flying = true,
	phases = { 0.66, 0.33 },
	reward = "bolt",
	geo = 260,
	run = function(b)
		local function pageVolley(count: number)
			b.faceTarget()
			b.telegraph(0.45)
			local origin = b.position + b.facing * 2
			b.fan(origin, b.targetPos() - origin, count, 0.2, 26, { color = PAGE, radius = 0.7, lifetime = 4, passWalls = true })
		end
		local function blink()
			b.dust(b.position)
			b.hide()
			local at = b.clamp(b.targetGround() + Vector3.new(b.rng:NextNumber(-4, 4), 0, b.rng:NextNumber(-4, 4)))
			b.marker(at, 3.5, b.pace(0.7))
			b.wait(b.pace(0.7))
			b.appear(Vector3.new(at.X, b.ceilY - b.size.Y, at.Z))
			b.telegraph(0.3)
			b.moveTo(Vector3.new(at.X, b.floorY + b.size.Y / 2, at.Z), 70, "attack")
			b.setAnim("slam", true)
			b.shake(0.7)
			b.shockwaves(22)
			b.wait(0.3)
			b.moveTo(Vector3.new(at.X, b.ceilY - b.size.Y - 2, at.Z), 24, "move")
		end
		while true do
			local roll = b.rng:NextInteger(1, if b.phase >= 2 then 4 else 3)
			if roll == 1 then
				b.moveTo(b.randomPoint(b.ceilY - b.rng:NextNumber(5, 9)), 22, "move")
				pageVolley(if b.phase >= 3 then 7 else 5)
				if b.phase >= 3 then
					b.wait(0.4)
					pageVolley(6)
				end
				b.rest(0.7)
			elseif roll == 2 then
				blink()
				b.rest(0.6)
			elseif roll == 3 then
				-- Ink rain: drops fall where the floor darkens.
				b.moveTo(Vector3.new(b.center().X, b.ceilY - 5, b.center().Z), 26, "move")
				b.telegraph(0.4)
				local spots = {}
				for _ = 1, if b.phase >= 3 then 13 else 9 do
					local t = b.targetGround()
					local p = b.clamp(t + Vector3.new(b.rng:NextNumber(-12, 12), 0, b.rng:NextNumber(-12, 12)))
					table.insert(spots, p)
					b.marker(p, 1.8, 0.55)
				end
				b.wait(0.55)
				for _, p in spots do
					b.projectile(Vector3.new(p.X, b.ceilY - 1, p.Z), Vector3.new(0, -32, 0), { color = INK, radius = 0.8, lifetime = 3, passWalls = true, quiet = true })
					b.wait(0.05)
				end
				b.rest(0.6)
			else
				-- The ink tide: the floor floods, and only the shelves are safe.
				b.moveTo(Vector3.new(b.center().X, b.ceilY - 4, b.center().Z), 26, "move")
				b.telegraph(0.6)
				b.inkTide(b.floorY + 5, if b.phase >= 3 then 4.5 else 3.5)
				pageVolley(5)
				b.wait(1.2)
				pageVolley(5)
				b.rest(2)
			end
		end
	end,
}
