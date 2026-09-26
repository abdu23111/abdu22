-- Sessa, the Glaive Dancer: first champion of the Hall of Trials. A dragonfly duelist who
-- throws her glaive like a boomerang, lunges the length of the hall and dives from above.
-- Phase 2 (half health): double throws, a whirling blade storm and a shockwave on every dive.

local PINK = Color3.fromRGB(255, 110, 190)

return {
	name = "Sessa",
	title = "The Glaive Dancer",
	hp = 170,
	size = Vector3.new(3, 7.5, 3),
	flying = false,
	phases = { 0.5 },
	geo = 120,
	onPhase = function(b)
		-- Wings flare: a burst of pink shards.
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			b.projectile(b.position + Vector3.new(0, 2, 0), Vector3.new(math.cos(a) * 26, math.sin(a) * 26, 0), { color = PINK, radius = 0.6, lifetime = 1.5, quiet = true })
		end
	end,
	run = function(b)
		local last = 0
		while true do
			local roll = b.rng:NextInteger(1, 4)
			if roll == last then
				roll = roll % 4 + 1
			end
			last = roll
			if roll == 1 then
				-- Glaive throw: it spins out at chest height and comes back to her hand.
				b.faceTarget()
				b.telegraph(b.pace(0.4))
				b.setAnim("throw", true)
				local speed = 62
				local from = b.position + Vector3.new(0, 1, 0)
				b.projectile(from, b.facing * speed, { color = PINK, radius = 1.3, accel = -b.facing * speed * 1.2, lifetime = 1.65, passWalls = true, quiet = true })
				if b.phase >= 2 then
					local v = b.facing * speed * 0.8 + Vector3.new(0, 10, 0)
					b.projectile(from + Vector3.new(0, 3, 0), v, { color = PINK, radius = 1.1, accel = -v * 1.2, lifetime = 1.65, passWalls = true, quiet = true })
				end
				b.wait(1.7, "idle")
				b.rest(0.3)
			elseif roll == 2 then
				-- Lunge: a blinding dash straight through where you stand.
				b.faceTarget()
				b.telegraph(b.pace(0.45))
				b.moveTo(b.position + b.facing * 50, 80, "attack")
				b.rest(0.55)
			elseif roll == 3 then
				-- Air dive: up to the ceiling, a moment's hover, then a diagonal plunge.
				b.faceTarget()
				b.flyTo(Vector3.new(b.position.X - b.facing.X * 8, b.ceilY - 12, 0), 60, "leap")
				b.faceTarget()
				b.wait(b.pace(0.35), "windup")
				local t = b.targetGround()
				b.marker(t, 2.5, 0.35)
				b.wait(0.2)
				b.flyTo(Vector3.new(t.X, b.groundY, 0), 100, "dive")
				b.setAnim("slam", true)
				b.shake(0.5)
				if b.phase >= 2 then
					b.shockwaves(34, 28)
				end
				b.rest(0.6)
			else
				-- Whirl: she spins in place with the glaive held out; stand clear.
				b.faceTarget()
				b.telegraph(b.pace(0.5))
				b.setAnim("spin", true)
				for i = 1, 6 do
					b.hazard(CFrame.new(b.position), Vector3.new(12, 8, 4), 0.14)
					if b.phase >= 2 and i % 2 == 0 then
						for k = 1, 4 do
							local a = (k / 4 + i * 0.07) * math.pi * 2
							b.projectile(b.position + Vector3.new(0, 1, 0), Vector3.new(math.cos(a) * 30, math.sin(a) * 30, 0), { color = PINK, radius = 0.6, lifetime = 1.4, quiet = true })
						end
					end
					b.wait(0.13)
				end
				b.rest(0.6)
			end
		end
	end,
}
