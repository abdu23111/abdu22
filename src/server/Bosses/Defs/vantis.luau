-- Sir Vantis, the Hollow Sentinel: the last knight of the capital, still on patrol.
-- Phase 2 (half health): his lunges send a shockwave and his thrusts come faster.

local MASK = Color3.fromRGB(232, 228, 218)

return {
	name = "Sir Vantis",
	title = "The Hollow Sentinel",
	hp = 190,
	size = Vector3.new(4, 8, 3.6),
	flying = false,
	phases = { 0.5 },
	reward = "claws",
	geo = 200,
	parts = {
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.6, 5.6, 3.2), offset = Vector3.new(0, -0.8, 0), color = Color3.fromRGB(60, 64, 88), anim = "breath" },
		{ size = Vector3.new(0.3, 5.4, 3), offset = Vector3.new(-1.8, -0.6, 0), color = Color3.fromRGB(120, 32, 44), anim = "cape" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(4.6, 1.6, 3.6), offset = Vector3.new(0, 1.8, 0), color = Color3.fromRGB(150, 156, 180), anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.2, 2.4, 2.2), offset = Vector3.new(0.4, 3.1, 0.3), color = MASK, anim = "breath" },
		{ size = Vector3.new(0.4, 2.4, 0.4), offset = Vector3.new(0, 4.6, 0), rz = -0.3, color = MASK, anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.7, 0.3), offset = Vector3.new(1.1, 3.1, 1.2), color = Color3.fromRGB(150, 210, 255), neon = true, anim = "breath" },
		{ size = Vector3.new(7, 0.4, 0.4), offset = Vector3.new(3.4, 0.4, 1), color = Color3.fromRGB(205, 205, 220) },
		{ size = Vector3.new(0.6, 2.4, 0.6), offset = Vector3.new(-0.7, -3, 0.5), color = Color3.fromRGB(40, 42, 56) },
		{ size = Vector3.new(0.6, 2.4, 0.6), offset = Vector3.new(0.7, -3, 0.5), color = Color3.fromRGB(40, 42, 56) },
	},
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				b.faceTarget()
				b.telegraph(0.45)
				b.moveTo(b.clampX(b.targetPos().X + b.dir * 7), b.groundY, 50)
				if b.phase >= 2 then
					b.shockwaves(30, b.dir)
				end
				b.wait(b.pace(0.55))
			elseif roll == 2 then
				b.telegraph(0.35)
				local x = b.clampX(b.targetPos().X)
				b.marker(x, 5, 0.45)
				b.leap(x, 22, 1.0)
				b.shake(0.6)
				b.shockwaves(32)
				b.wait(b.pace(0.6))
			else
				for _ = 1, if b.phase >= 2 then 4 else 3 do
					b.faceTarget()
					b.telegraph(b.pace(0.25))
					b.moveTo(b.clampX(b.position.X + b.dir * 9), b.groundY, 38)
					b.wait(0.12)
				end
				b.wait(b.pace(0.7))
			end
		end
	end,
}
