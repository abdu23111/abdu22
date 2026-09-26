-- Sir Vantis, the Hollow Sentinel: the capital's last knight, still on patrol.
-- Lunges with his lance, leaps into crashing slams and pushes forward in rapid thrusts.
-- Phase 2 (half health): lunges end in a shockwave, thrusts come in fours.

return {
	name = "Sir Vantis",
	title = "The Hollow Sentinel",
	hp = 190,
	size = Vector3.new(4, 8, 3.6),
	flying = false,
	phases = { 0.5 },
	reward = "claws",
	geo = 200,
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				b.faceTarget()
				b.telegraph(0.45)
				local t = b.targetGround()
				b.moveTo(t + b.facing * 7, 52, "attack")
				if b.phase >= 2 then
					b.shockwaves(28, 30)
				end
				b.rest(0.6)
			elseif roll == 2 then
				b.faceTarget()
				b.telegraph(0.35)
				local at = b.clamp(b.targetGround())
				b.marker(at, 3.5, 1.0)
				b.leap(at, 22, 1.0)
				b.shake(0.7)
				b.shockwaves(30)
				b.rest(0.6)
			else
				for _ = 1, if b.phase >= 2 then 4 else 3 do
					b.faceTarget()
					b.telegraph(b.pace(0.28))
					b.moveTo(b.position + b.facing * 9, 38, "attack")
					b.wait(0.12)
				end
				b.rest(0.7)
			end
		end
	end,
}
