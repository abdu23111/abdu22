-- Mirra, the Reed Skater: second champion. A water strider who skims the floor, flings reed
-- sickles that curve back to her, and springs off the hall's walls in long diagonal lunges.
-- Phase 2 (half health): lunges come in pairs from both walls; skating leaves reed spikes.

local REED = Color3.fromRGB(170, 235, 100)

return {
	name = "Mirra",
	title = "The Reed Skater",
	hp = 200,
	size = Vector3.new(6, 4.5, 4),
	flying = false,
	phases = { 0.5 },
	geo = 150,
	run = function(b)
		local last = 0
		while true do
			local roll = b.rng:NextInteger(1, 4)
			if roll == last then
				roll = roll % 4 + 1
			end
			last = roll
			if roll == 1 then
				-- Skate: across the whole hall in one glide.
				b.faceTarget()
				b.telegraph(b.pace(0.35))
				local goal = if b.facing.X > 0 then b.maxX else b.minX
				local spikeTimer = 0
				b.setAnim("move")
				local target = b.clamp(Vector3.new(goal, b.groundY, 0))
				while math.abs(target.X - b.position.X) > 0.5 do
					local dt = b.step()
					local d = target.X - b.position.X
					b.position += Vector3.new(math.sign(d) * math.min(math.abs(d), 70 * dt), 0, 0)
					spikeTimer -= dt
					if b.phase >= 2 and spikeTimer <= 0 then
						spikeTimer = 0.3
						b.projectile(b.position + Vector3.new(0, 1, 0), Vector3.new(0, 34, 0), { color = REED, radius = 0.6, gravity = 60, lifetime = 1.6, quiet = true })
					end
				end
				b.rest(0.45)
			elseif roll == 2 then
				-- Reed sickles: one skims low, one arcs high; both come back.
				b.faceTarget()
				b.telegraph(b.pace(0.4))
				b.setAnim("throw", true)
				local low = b.facing * 58
				local high = b.facing * 48 + Vector3.new(0, 16, 0)
				b.projectile(b.position + Vector3.new(0, -0.5, 0), low, { color = REED, radius = 1.0, accel = -low * 1.25, lifetime = 1.6, passWalls = true, quiet = true })
				b.wait(0.25)
				b.projectile(b.position + Vector3.new(0, 2, 0), high, { color = REED, radius = 1.0, accel = -high * 1.25, lifetime = 1.6, passWalls = true, quiet = true })
				b.wait(1.4, "idle")
				b.rest(0.3)
			elseif roll == 3 then
				-- Wall lunge: she vanishes, clings high on a wall, then springs at you.
				local sides = if b.phase >= 2 then 2 else 1
				local first = if b.rng:NextNumber() < 0.5 then -1 else 1
				for n = 1, sides do
					local side = if n == 1 then first else -first
					local x = if side < 0 then b.minX else b.maxX
					b.teleport(Vector3.new(x, b.groundY + 16, 0), REED)
					b.faceTarget()
					b.telegraph(b.pace(0.45))
					local t = b.targetGround()
					b.flyTo(Vector3.new(t.X + b.facing.X * 6, b.groundY, 0), 95, "dive")
					b.setAnim("slam", true)
					b.shake(0.4)
					b.wait(0.25)
				end
				b.rest(0.5)
			else
				-- Ceiling drop: gone, a mark on the floor, then down from above.
				b.hide()
				local t = b.targetGround()
				b.marker(t, 3, 0.6)
				b.wait(0.6)
				b.position = b.clampAir(Vector3.new(t.X, b.ceilY - 6, 0))
				b.hidden = false
				b.flyTo(Vector3.new(t.X, b.groundY, 0), 110, "dive")
				b.setAnim("slam", true)
				b.shake(0.6)
				b.shockwaves(30, 24)
				b.rest(0.6)
			end
		end
	end,
}
