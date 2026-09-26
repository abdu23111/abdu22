-- The Hollow Warden: third champion. A suit of bronze armour worn by a grub far too small
-- for it, swinging a spiked mace. Every blow shakes rubble from the ceiling.
-- Phase 2 (half health): the armour splits and the Warden flies into a rage of slams.

local STONE = Color3.fromRGB(150, 140, 128)

return {
	name = "The Hollow Warden",
	title = "Armour Without a Knight",
	hp = 280,
	size = Vector3.new(7, 9, 6),
	flying = false,
	phases = { 0.5 },
	geo = 180,
	onPhase = function(b)
		for i = 1, 8 do
			local a = i / 8 * math.pi
			b.projectile(b.position + Vector3.new(0, 3, 0), Vector3.new(math.cos(a) * 24, math.sin(a) * 30, 0), { color = Color3.fromRGB(190, 150, 100), radius = 0.8, gravity = 60, lifetime = 2.5, quiet = true })
		end
	end,
	run = function(b)
		local function rubble(count: number)
			for _ = 1, count do
				local x = b.rng:NextNumber(b.minX, b.maxX)
				b.marker(Vector3.new(x, b.floorY, 0), 1.6, 0.7)
				task.delay(0.35, function()
					if not b.cancelled then
						b.projectile(Vector3.new(x, b.ceilY - 2, 0), Vector3.new(0, -6, 0), { color = STONE, radius = 1.2, gravity = 90, lifetime = 3, quiet = true })
					end
				end)
			end
		end
		local function smash()
			b.telegraph(b.pace(0.55))
			b.setAnim("attack", true)
			b.wait(0.12)
			local front = b.position + b.facing * 7
			b.hazard(CFrame.new(front.X, b.floorY + 3, 0), Vector3.new(8, 6, 4), 0.2)
			b.dust(Vector3.new(front.X, b.floorY, 0))
			b.shake(0.8)
			b.shockwaves(28, 40)
			rubble(if b.phase >= 2 then 4 else 2)
			b.wait(0.4)
		end
		while true do
			local roll = b.rng:NextInteger(1, 4)
			if roll == 1 then
				-- Stomp in and bring the mace down.
				b.faceTarget()
				local t = b.targetGround()
				if math.abs(t.X - b.position.X) > 12 then
					b.moveTo(t - b.facing * 9, 18, "move")
				end
				b.faceTarget()
				if b.phase >= 2 then
					for _ = 1, 3 do
						smash()
						b.faceTarget()
						b.moveTo(b.position + b.facing * 6, 30, "move")
					end
				else
					smash()
				end
				b.rest(0.8)
			elseif roll == 2 then
				-- A crushing leap onto the player.
				b.faceTarget()
				b.telegraph(b.pace(0.4))
				local at = b.clamp(b.targetGround())
				b.marker(at, 4, 1.1)
				b.leap(at, 26, 1.1)
				b.shake(1)
				b.shockwaves(32, 40)
				rubble(3)
				b.rest(0.8)
			elseif roll == 3 then
				-- A mad charge into the wall, bringing the ceiling down.
				b.faceTarget()
				b.telegraph(b.pace(0.6))
				local goal = if b.facing.X > 0 then b.maxX else b.minX
				b.moveTo(Vector3.new(goal, b.groundY, 0), 40, "move")
				b.setAnim("stagger", true)
				b.shake(1.2)
				rubble(if b.phase >= 2 then 8 else 5)
				b.wait(1.0)
				b.rest(0.4)
			else
				-- Bellow: rubble everywhere while it roars.
				b.setAnim("roar", true)
				b.shake(0.8)
				rubble(if b.phase >= 2 then 7 else 5)
				b.wait(1.6)
				b.rest(0.5)
			end
		end
	end,
}
