--!strict
-- Pure data (no requires) so it can be loaded under Lune for catalog tests.

local Rarities = {
	-- Display order, lowest to highest.
	order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },

	-- Roll weights for a generic random pull (daily pack). Higher = more common.
	weights = {
		Common = 60,
		Uncommon = 25,
		Rare = 10,
		Epic = 4,
		Legendary = 0.9,
		Mythic = 0.1,
	},

	-- Coins granted when an extra duplicate is auto-converted (anti-duplication).
	dupeValue = {
		Common = 10,
		Uncommon = 25,
		Rare = 75,
		Epic = 250,
		Legendary = 1000,
		Mythic = 5000,
	},

	-- Progressive global-market tax (fraction of sale price) by card rarity.
	marketTax = {
		Common = 0.05,
		Uncommon = 0.07,
		Rare = 0.10,
		Epic = 0.15,
		Legendary = 0.20,
		Mythic = 0.25,
	},

	auraMaxLevel = 5,
}

return Rarities
