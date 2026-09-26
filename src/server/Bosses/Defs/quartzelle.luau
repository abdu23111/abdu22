-- Quartzelle, the Facet Matron: a crystal-grown beetle queen whose blade is the Cleaving Arc.
-- Crystal spires erupt around the player, prism beams sweep the chamber, and she sprints
-- through it trailing shards. Phase 2 (half health): her shell shatters; twin beams, faster.

local CRYSTAL = Color3.fromRGB(240, 150, 255)

return {
	name = "Quartzelle",
	title = "The Facet Matron",
	hp = 240,
	size = Vector3.new(7, 7.5, 5),
	flying = false,
	phases = { 0.5 },
	reward = "cleave",
	geo = 220,
	onPhase = function(b)
		-- The shell cracks away: a spray of crystal in every direction.
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			b.projectile(b.position, Vector3.new(math.cos(a) * 22, 14, math.sin(a) * 22), { color = CRYSTAL, radius = 0.7, gravity = 40, lifetime = 2.5, quiet = true })
		end
	end,
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				-- Crystal eruption: a ring of glowing marks around the player, then spires.
				b.faceTarget()
				b.telegraph(0.5)
				local t = b.targetGround()
				local spots = { b.clamp(t) }
				local n = if b.phase >= 2 then 6 else 4
				for i = 1, n do
					local a = i / n * math.pi * 2 + b.rng:NextNumber(0, 0.5)
					table.insert(spots, b.clamp(t + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)))
				end
				for _, s in spots do
					b.marker(s, 1.8, 0.75)
				end
				b.wait(0.75, "shoot")
				for _, s in spots do
					b.spire(s, 11, 0.7)
				end
				b.shake(0.5)
				b.rest(0.9)
			elseif roll == 2 then
				-- Prism beam: she rears back, a warning line crosses the chamber, then light.
				b.faceTarget()
				local base = b.targetPos() - b.position
				local angles = if b.phase >= 2 then { -0.35, 0.35 } else { 0 }
				local from = b.position + Vector3.new(0, 1, 0)
				for _, a in angles do
					local dir = b.rotate(base.Unit, a)
					b.beamWarn(from, dir, 90, 0.8)
				end
				b.telegraph(0.8)
				b.setAnim("shoot", true)
				for _, a in angles do
					local dir = b.rotate(base.Unit, a)
					b.beam(from, dir, 90, 0.45)
				end
				b.shake(0.6)
				b.rest(0.9)
			else
				-- Shard charge: sprints through the player, crystals spraying up behind her.
				b.faceTarget()
				b.telegraph(0.5)
				local goal = b.clamp(b.position + b.facing * 70)
				local sprayTimer = 0
				local speed = if b.phase >= 2 then 40 else 32
				b.setAnim("attack")
				while (goal - b.position).Magnitude > 0.5 do
					local dt = b.step()
					sprayTimer -= dt
					local d = goal - b.position
					b.position += d.Unit * math.min(d.Magnitude, speed * dt)
					if sprayTimer <= 0 then
						sprayTimer = 0.18
						local side = Vector3.new(-b.facing.Z, 0, b.facing.X) * b.rng:NextNumber(-8, 8)
						b.projectile(b.position + Vector3.new(0, 2, 0), -b.facing * b.rng:NextNumber(4, 10) + side + Vector3.new(0, b.rng:NextNumber(26, 36), 0), { color = CRYSTAL, radius = 0.6, gravity = 70, lifetime = 3, quiet = true })
					end
				end
				b.shake(0.6)
				if b.phase >= 2 then
					b.shockwaves(30)
				end
				b.rest(0.8)
			end
		end
	end,
}
