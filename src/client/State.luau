-- Shared client-side state: the current character and a few flags other modules read.

local State = {
	character = nil :: Model?,
	humanoid = nil :: Humanoid?,
	root = nil :: BasePart?,
	facing = 1,
	grounded = false,
	zone = nil :: number?,
	-- Movement is paused while any of these reasons is active (dialogue, transitions, death...).
	freezes = {} :: { [string]: boolean },
}

function State.freeze(reason: string, on: boolean)
	State.freezes[reason] = if on then true else nil
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
