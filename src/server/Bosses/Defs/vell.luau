-- Magister Vell, the Lantern Sorcerer: fourth champion. He drifts above the floor, blinks
-- from place to place, and hurls seeking lantern-light. Now and then he drops like a stone.
-- Phase 2 (half health): more orbs, double rings, and a sweeping beam of cold light.

local LIGHT = Color3.fromRGB(150, 220, 255)

return {
	name = "Magister Vell",
	title = "The Lantern Sorcerer",
	hp = 230,
	size = Vector3.new(4, 7, 4),
	flying = true,
	phases = { 0.5 },
	geo = 200,
	run = function(b)
		local hover = function(): Vector3
			return Vector3.new(b.rng:NextNumber(b.minX + 8, b.maxX - 8), b.groundY + b.rng:NextNumber(10, 18), 0)
		end
		local last = 0
		while true do
			local roll = b.rng:NextInteger(1, 4)
			if roll == last then
				roll = roll % 4 + 1
			end
			last = roll
			if roll == 1 then
				-- Seeking lanterns: slow orbs that follow you until they burn out.
				b.faceTarget()
				b.telegraph(b.pace(0.6))
				local n = if b.phase >= 2 then 5 else 3
				for i = 1, n do
					local a = i / n * math.pi * 2
					local at = b.position + Vector3.new(math.cos(a) * 3.5, math.sin(a) * 3.5, 0)
					b.projectile(at, Vector3.new(math.cos(a), math.sin(a), 0) * 20, { color = LIGHT, radius = 0.9, homing = 1.4, lifetime = 4.2, passWalls = true, quiet = true })
				end
				b.setAnim("shoot", true)
				b.wait(1.2, "idle")
				b.flyTo(hover(), 30, "move")
			elseif roll == 2 then
				-- Lantern ring: a circle of light bursting outward.
				b.telegraph(b.pace(0.5))
				local rings = if b.phase >= 2 then 2 else 1
				for k = 1, rings do
					b.setAnim("shoot", true)
					for i = 1, 12 do
						local a = (i + k * 0.5) / 12 * math.pi * 2
						b.projectile(b.position, Vector3.new(math.cos(a) * 26, math.sin(a) * 26, 0), { color = LIGHT, radius = 0.8, lifetime = 3, passWalls = true, quiet = true })
					end
					b.wait(0.45)
				end
				b.rest(0.5)
			elseif roll == 3 then
				-- Plunge: he blinks above you and drops.
				local t = b.targetGround()
				b.teleport(Vector3.new(t.X, b.ceilY - 10, 0), LIGHT)
				b.marker(Vector3.new(t.X, b.floorY, 0), 3, 0.5)
				b.telegraph(b.pace(0.5))
				b.flyTo(Vector3.new(t.X, b.groundY, 0), 110, "dive")
				b.setAnim("slam", true)
				b.shake(0.7)
				b.shockwaves(30, 36)
				b.wait(0.5)
				b.flyTo(hover(), 30, "move")
			else
				-- Cold beam: from the edge of the hall, straight across at your height.
				local side = if b.targetPos().X > (b.minX + b.maxX) / 2 then -1 else 1
				local x = if side < 0 then b.minX else b.maxX
				b.teleport(Vector3.new(x, b.targetPos().Y, 0), LIGHT)
				b.faceTarget()
				local dir = Vector3.new(-side, 0, 0)
				local from = b.position + Vector3.new(0, 1, 0)
				local length = b.maxX - b.minX + 10
				b.beamWarn(from, dir, length, 0.75)
				if b.phase >= 2 then
					b.beamWarn(from + Vector3.new(0, 9, 0), dir, length, 0.75)
				end
				b.telegraph(0.75)
				b.setAnim("shoot", true)
				b.beam(from, dir, length, 0.5, LIGHT)
				if b.phase >= 2 then
					b.beam(from + Vector3.new(0, 9, 0), dir, length, 0.5, LIGHT)
				end
				b.shake(0.5)
				b.wait(0.6)
				b.flyTo(hover(), 30, "move")
			end
		end
	end,
}
