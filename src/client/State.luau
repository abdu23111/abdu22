-- Shared client-side state: the current character and a few flags other modules read.

local State = {
	character = nil :: Model?,
	humanoid = nil :: Humanoid?,
	root = nil :: BasePart?,
	facing = 1,
	grounded = false,
	zone = nil :: number?,
	bossFight = false,
	cameraYaw = 0,
	lockTarget = nil :: BasePart?,
	-- Animation hints written by Movement / combat and read by the character animator.
	action = nil :: string?, -- "dash" | "dodge" | "wall" | "heal" | "swing" | nil
	moveSpeed = 0,
	facingVector = Vector3.xAxis,
	talkingTo = nil :: string?,
	charging = false,
	swingAnchor = nil :: Vector3?, -- the ring the Silkline is hooked to
	invulnUntil = 0,
	dead = false,
	-- Movement is paused while any of these reasons is active (dialogue, transitions, death...).
	freezes = {} :: { [string]: boolean },
}

function State.freeze(reason: string, on: boolean)
	State.freezes[reason] = if on then true else nil
end

local UI_REASONS = { dialogue = true, charms = true, journal = true, memory = true }

-- True while a menu that needs the mouse cursor is open.
function State.uiOpen(): boolean
	for reason in State.freezes do
		if UI_REASONS[reason] then
			return true
		end
	end
	return false
end

function State.frozen(): boolean
	return next(State.freezes) ~= nil
end

function State.hasAbility(attribute: string): boolean
	return game:GetService("Players").LocalPlayer:GetAttribute(attribute) == true
end

function State.hasCharm(id: string): boolean
	local raw = game:GetService("Players").LocalPlayer:GetAttribute("CharmsEquipped")
	if typeof(raw) ~= "string" then
		return false
	end
	return string.find(raw, '"' .. id .. '"', 1, true) ~= nil
end

return State
