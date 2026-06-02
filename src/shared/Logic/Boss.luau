--!strict
-- PURE co-op boss logic. No Roblox globals, no requires -> Lune-testable.

local Boss = {}

-- Apply damage to the boss hp, floored at 0.
function Boss.applyDamage(hp: number, dmg: number): number
	return math.max(0, hp - dmg)
end

-- True when the boss has been defeated.
function Boss.isDead(hp: number): boolean
	return hp <= 0
end

-- Split totalReward evenly among participantCount players (floor division).
-- Guard against division by zero: treats 0 participants as 1.
function Boss.splitReward(totalReward: number, participantCount: number): number
	return math.floor(totalReward / math.max(1, participantCount))
end

return Boss
