--!strict
-- PURE shield logic. No requires, no Roblox globals -> Lune-testable.
-- Config (durationSeconds) is injected by callers.

type ShieldState = {
	active: boolean,
	expiresAt: number,
}

local Shield = {}

-- Returns true when the shield is both flagged active AND has not yet expired.
function Shield.isActive(shield: ShieldState, now: number): boolean
	return shield.active and now < shield.expiresAt
end

-- Build a fresh active shield that expires `duration` seconds from `now`.
function Shield.activate(now: number, duration: number): ShieldState
	return { active = true, expiresAt = now + duration }
end

-- Seconds of protection remaining. Returns 0 when inactive or already expired.
function Shield.remaining(shield: ShieldState, now: number): number
	if not shield.active then
		return 0
	end
	local left = shield.expiresAt - now
	return if left > 0 then left else 0
end

return Shield
