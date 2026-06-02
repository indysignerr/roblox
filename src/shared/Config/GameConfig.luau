--!strict
-- Central tunables locked from the GDD ("version propre à garder").
-- Pure data (no requires) so logic tests can import it under Lune.

local GameConfig = {
	startingCoins = 100,

	-- Protection shield: 10 min after being stolen from, then paid reactivation.
	shield = {
		durationSeconds = 600,
		reactivateCost = 500,
	},

	-- Risky fusion: 5 Rare -> 1 Epic at 80% success.
	fusion = {
		inputRarity = "Rare",
		inputCount = 5,
		outputRarity = "Epic",
		successRate = 0.80,
	},

	-- Team Manager: 1 Manager + 2 Captains + 8 Players = 11.
	team = {
		maxSize = 11,
		managers = 1,
		captains = 2,
		players = 8,
		leaveCooldownHours = 24,
	},

	packs = {
		dailyResetHour = 0, -- minuit, heure serveur
		flashDurationSeconds = 600,
		nationPackCoinCost = 1500,
		nationPackRobuxCost = 100,
	},

	-- Nation leaderboard: mixed score (collection value + wins).
	nationScore = {
		collectionValueWeight = 0.5,
		winsWeight = 0.5,
	},

	-- Spy feature is Robux-only.
	spyRobuxCost = 25,
}

return GameConfig
