--!strict
-- Roblox Developer Product IDs (one-time / consumable purchases).
--
-- HOW TO FILL THIS IN:
--   1. Publish the game, then open it on create.roblox.com.
--   2. Monetization -> Developer Products -> Create a product for each entry below.
--   3. Copy each product's numeric ID into `productId` here.
-- A `productId = 0` means "not configured yet" -> that purchase is disabled (the
-- server simply won't prompt or grant it), so the game still runs without real IDs.
--
-- The reward keys (coins / spyCredits) are granted server-side by PurchaseService
-- inside MarketplaceService.ProcessReceipt -- NEVER trust the client for these.

export type ProductEntry = {
	productId: number,
	coins: number?,
	spyCredits: number?,
}

local ProductConfig: { [string]: ProductEntry } = {
	-- One reveal of a rival's full collection (consumed by SocialService:Spy).
	spyReveal = { productId = 0, spyCredits = 1 },

	-- Coin bundles (the larger bundles give bonus coins for value).
	coinsSmall = { productId = 0, coins = 1000 },
	coinsMedium = { productId = 0, coins = 5500 },
	coinsLarge = { productId = 0, coins = 12000 },
}

return ProductConfig
