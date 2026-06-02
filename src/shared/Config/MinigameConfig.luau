--!strict
-- Tunables for the Minigames system (penalty shootout + co-op boss).
-- Pure data (no requires) -> loads under Lune.

local MinigameConfig = {
	penalty = {
		goalReward = 100,
		missReward = 10,
	},
	boss = {
		maxHp = 10000,
		totalReward = 5000,
		rewardCardChance = 0.25,
	},
}

return MinigameConfig
