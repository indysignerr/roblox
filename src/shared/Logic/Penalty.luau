--!strict
-- PURE penalty-shootout logic. No Roblox globals, no requires -> Lune-testable.
-- Directions are integers 1..5. The keeper saves only on an exact direction match.

type PenaltyCfg = {
	goalReward: number,
	missReward: number,
}

local Penalty = {}

-- Returns true when the shot scores (shotDir ~= keeperDir).
function Penalty.resolve(shotDir: number, keeperDir: number): boolean
	return shotDir ~= keeperDir
end

-- Returns the coin reward for the outcome.
function Penalty.reward(isGoal: boolean, cfg: PenaltyCfg): number
	return if isGoal then cfg.goalReward else cfg.missReward
end

return Penalty
