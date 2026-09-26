-- Gravelmaw, the Tunneling Mother: a colossal grub who guards the Ashen Burrows.
-- Charges through the chamber shaking stones from the ceiling, leaps onto intruders, and
-- burrows to burst up beneath them. Phase 2 (half health): faster, with more falling stone.

local STONE = Color3.fromRGB(150, 140, 130)

return {
	name = "Gravelmaw",
	title = "The Tunneling Mother",
	hp = 130,
	size = Vector3.new(9, 5.6, 6),
	flying = false,
	phases = { 0.5 },
	reward = "dash",
	geo = 120,
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				-- Charge through the player's position to the far wall.
				b.faceTarget()
				b.telegraph(0.6)
				local through = b.position + b.facing * 60
				b.moveTo(through, 32, "attack")
				b.shake(0.8)
				local spots = {}
				for _ = 1, if b.phase >= 2 then 8 else 5 do
					local t = b.targetGround()
					local spot = b.clamp(t + Vector3.new(b.rng:NextNumber(-10, 10), 0, b.rng:NextNumber(-10, 10)))
					table.insert(spots, spot)
					b.marker(spot, 2.2, 0.6)
				end
				b.wait(0.6, "idle")
				for _, spot in spots do
					b.projectile(Vector3.new(spot.X, b.ceilY - 1.5, spot.Z), Vector3.new(0, -30, 0), { gravity = 70, color = STONE, radius = 1.2, lifetime = 3, quiet = true })
				end
				b.rest(0.9)
			elseif roll == 2 then
				-- Leap onto the player and send a ring of force through the floor.
				b.faceTarget()
				b.telegraph(0.45)
				local at = b.clamp(b.targetGround())
				b.marker(at, 4, 0.9)
				b.leap(at, 16, 0.9)
				b.shake(0.7)
				b.shockwaves(26)
				b.rest(0.8)
			else
				-- Burrow, then erupt beneath the player.
				b.moveTo(Vector3.new(b.position.X, b.floorY - b.size.Y, b.position.Z), 14, "burrow")
				b.hidden = true
				b.wait(0.4)
				local at = b.clamp(b.targetGround())
				b.position = Vector3.new(at.X, b.position.Y, at.Z)
				b.dust(Vector3.new(at.X, b.floorY, at.Z))
				b.marker(at, 4, b.pace(0.8))
				b.wait(b.pace(0.8))
				b.hidden = false
				b.faceTarget()
				b.moveTo(Vector3.new(at.X, b.groundY, at.Z), 46, "attack")
				b.setAnim("slam", true)
				b.shake(0.6)
				for i = 1, 6 do
					local a = i / 6 * math.pi * 2
					b.projectile(b.position + Vector3.new(0, 2, 0), Vector3.new(math.cos(a) * 9, 34, math.sin(a) * 9), { gravity = 70, color = STONE, radius = 0.9, lifetime = 3, quiet = true })
				end
				b.rest(0.9)
			end
		end
	end,
}
