-- The Thornwidow, Weaver of Wings: she wove the choir's wings and waits for them to return.
-- Web volleys, a ceiling stalk that ends in a crushing drop, and scuttling lunges.
-- Phase 2 (half health): double volleys, and silk rains down while she stalks.

local WEB = Color3.fromRGB(235, 235, 245)

return {
	name = "The Thornwidow",
	title = "Weaver of Wings",
	hp = 230,
	size = Vector3.new(8, 5, 6),
	flying = false,
	phases = { 0.5 },
	reward = "wings",
	geo = 260,
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				for _ = 1, if b.phase >= 2 then 2 else 1 do
					b.faceTarget()
					b.telegraph(0.4)
					local origin = b.position + Vector3.new(0, 1, 0)
					b.fan(origin, b.targetPos() - origin, 5, 0.22, 30, { color = WEB, radius = 0.8, lifetime = 3 })
					b.wait(0.5)
				end
				b.rest(0.5)
			elseif roll == 2 then
				-- Climb to the ceiling, stalk the player, then drop.
				local top = b.ceilY - b.size.Y / 2
				b.moveTo(Vector3.new(b.position.X, top, b.position.Z), 34, "leap")
				local stalk, dropTimer = 1.4, 0
				while stalk > 0 do
					local dt = b.step()
					stalk -= dt
					dropTimer -= dt
					local t = b.clamp(b.targetGround())
					local d = Vector3.new(t.X - b.position.X, 0, t.Z - b.position.Z)
					if d.Magnitude > 0 then
						b.position += d.Unit * math.min(d.Magnitude, 24 * dt)
					end
					if b.phase >= 2 and dropTimer <= 0 then
						dropTimer = 0.3
						local p = b.randomPoint()
						b.projectile(Vector3.new(p.X, top, p.Z), Vector3.new(0, -26, 0), { color = WEB, radius = 0.6, lifetime = 3, quiet = true })
					end
				end
				b.marker(Vector3.new(b.position.X, b.groundY, b.position.Z), 4.5, 0.45)
				b.telegraph(0.45)
				b.moveTo(Vector3.new(b.position.X, b.groundY, b.position.Z), 80, "attack")
				b.shake(0.8)
				b.shockwaves(24)
				b.rest(0.8)
			else
				b.faceTarget()
				b.telegraph(0.35)
				b.moveTo(b.targetGround() + b.facing * 4, 42, "attack")
				b.rest(0.6)
			end
		end
	end,
}
