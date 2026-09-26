-- Quartzelle, the Facet Matron: a crystal-grown beetle queen who keeps her brood singing
-- inside the stone. Her crystal blade is the Cleaving Arc.
-- Phase 2 (half health): her shell shatters; she moves faster and fires two prism beams.

local MASK = Color3.fromRGB(232, 228, 218)
local CRYSTAL = Color3.fromRGB(240, 150, 255)
local SHELL = Color3.fromRGB(70, 54, 92)

local parts = {
	{ shape = Enum.PartType.Ball, size = Vector3.new(5, 4.5, 5), offset = Vector3.new(-2.2, -0.8, 0), color = SHELL, anim = "breath" },
	{ shape = Enum.PartType.Ball, size = Vector3.new(3.6, 4, 4), offset = Vector3.new(0.8, 0, 0), color = Color3.fromRGB(84, 64, 110), anim = "breath" },
	{ shape = Enum.PartType.Ball, size = Vector3.new(2.6, 2.6, 2.6), offset = Vector3.new(2.6, 1.6, 0.4), color = MASK, anim = "breath" },
	{ shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.8, 0.3), offset = Vector3.new(3.4, 1.9, 1.6), color = Color3.fromRGB(255, 120, 230), neon = true, anim = "breath" },
	{ shape = Enum.PartType.Ball, size = Vector3.new(0.45, 0.7, 0.3), offset = Vector3.new(2.8, 2.0, 1.7), color = Color3.fromRGB(255, 120, 230), neon = true, anim = "breath" },
	{ size = Vector3.new(0.8, 2.6, 0.8), offset = Vector3.new(2.4, 3.4, 0), rz = -0.3, color = CRYSTAL, neon = true, transparency = 0.15, anim = "breath" },
	{ size = Vector3.new(0.6, 2, 0.6), offset = Vector3.new(1.9, 3.2, 0.6), rz = 0.25, color = CRYSTAL, neon = true, transparency = 0.15, anim = "breath" },
	{ size = Vector3.new(0.6, 1.8, 0.6), offset = Vector3.new(3.0, 3.0, -0.4), rz = -0.6, color = CRYSTAL, neon = true, transparency = 0.15, anim = "breath" },
	{ size = Vector3.new(1, 3.5, 1), offset = Vector3.new(-2.4, 2.2, 0), rz = 0.3, color = CRYSTAL, neon = true, transparency = 0.2, anim = "breath" },
	{ size = Vector3.new(0.8, 2.6, 0.8), offset = Vector3.new(-3.6, 1.4, 0.5), rz = 0.7, color = CRYSTAL, neon = true, transparency = 0.2, anim = "breath" },
	{ size = Vector3.new(0.6, 5, 0.6), offset = Vector3.new(3.6, -0.6, 1.4), rz = 0.9, color = Color3.fromRGB(255, 200, 255), neon = true },
}
for i = 1, 3 do
	table.insert(parts, { size = Vector3.new(0.4, 2.6, 0.4), offset = Vector3.new(-2.6 + i * 1.4, -3, 1.4), rz = if i % 2 == 0 then 0.4 else -0.4, color = Color3.fromRGB(30, 24, 44), anim = if i % 2 == 0 then "leg" else "legB" })
end

return {
	name = "Quartzelle",
	title = "The Facet Matron",
	hp = 240,
	size = Vector3.new(7, 7.5, 5),
	flying = false,
	phases = { 0.5 },
	reward = "cleave",
	geo = 220,
	parts = parts,
	onPhase = function(b, phase: number)
		if phase == 2 then
			-- The shell cracks away: a spray of crystal in every direction.
			for i = 1, 10 do
				local a = i / 10 * math.pi * 2
				b.projectile(b.position, Vector3.new(math.cos(a), math.abs(math.sin(a)) + 0.3, 0) * 22, { color = CRYSTAL, radius = 0.7, gravity = 40, lifetime = 2.5 })
			end
		end
	end,
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				-- Crystal eruption: glowing marks on the floor, then spires burst up.
				b.telegraph(0.5)
				local target = b.targetPos().X
				local xs = {}
				for i = 1, if b.phase >= 2 then 5 else 3 do
					table.insert(xs, b.clampX(target + (i - (if b.phase >= 2 then 3 else 2)) * 7 + b.rng:NextNumber(-1.5, 1.5)))
				end
				for _, x in xs do
					b.marker(x, 3.4, 0.7)
				end
				b.wait(0.7)
				for _, x in xs do
					b.spire(x, 11, 0.7)
				end
				b.shake(0.4)
				b.wait(b.pace(0.9))
			elseif roll == 2 then
				-- Prism beam: she rears back, a warning line crosses the arena, then light.
				b.faceTarget()
				local heights = { b.floorY + 2.5 }
				if b.phase >= 2 then
					heights = { b.floorY + 2.5, b.floorY + 11 }
					if b.rng:NextNumber() < 0.5 then
						heights = { b.floorY + 11, b.floorY + 2.5 }
					end
				end
				for _, y in heights do
					b.beamWarn(y, 0.75)
					b.telegraph(0.75)
					b.beam(y, 0.45)
					b.shake(0.5)
					b.wait(0.3)
				end
				b.wait(b.pace(0.8))
			else
				-- Shard charge: sprints across, crystals spraying up behind her.
				b.faceTarget()
				b.telegraph(0.5)
				local goal = if b.dir > 0 then b.maxX else b.minX
				local sprayTimer = 0
				local speed = if b.phase >= 2 then 40 else 32
				while math.abs(goal - b.position.X) > 0.5 do
					local dt = b.step()
					sprayTimer -= dt
					local stepX = math.clamp(goal - b.position.X, -speed * dt, speed * dt)
					b.position += Vector3.new(stepX, 0, 0)
					if sprayTimer <= 0 then
						sprayTimer = 0.18
						b.projectile(b.position + Vector3.new(0, 2, 0), Vector3.new(-b.dir * b.rng:NextNumber(4, 12), b.rng:NextNumber(26, 36), 0), { color = CRYSTAL, radius = 0.6, gravity = 70, lifetime = 3 })
					end
				end
				b.shake(0.6)
				if b.phase >= 2 then
					b.shockwaves(30, -b.dir)
				end
				b.wait(b.pace(0.8))
			end
		end
	end,
}
