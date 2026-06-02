--!strict
-- PURE trade-offer validation. No requires, no Roblox -> Lune-testable.
-- An offer describes what one side of a P2P trade puts on the table.

export type Offer = {
	cardIds: { string }, -- may contain duplicates (offering 2 copies of the same card)
	coins: number,
}

-- OwnedCard shape used by the pure layer (mirrors Types.OwnedCard, without importing it).
type OwnedCard = { cardId: string, count: number, aura: number }
type Cards = { [string]: OwnedCard }

local Trade = {}

-- Returns (true, "") when the owner can fulfil the offer, or (false, reason) otherwise.
-- Validates:
--   - owner has enough copies of every card in cardIds (counts duplicates in the list).
--   - owner has >= offer.coins.
function Trade.validateOffer(ownerCards: Cards, ownerCoins: number, offer: Offer): (boolean, string)
	-- Count how many copies of each cardId are requested.
	local needed: { [string]: number } = {}
	for _, cardId in offer.cardIds do
		needed[cardId] = (needed[cardId] or 0) + 1
	end

	-- Verify card holdings.
	for cardId, count in needed do
		local owned = ownerCards[cardId]
		if not owned or owned.count < count then
			return false,
				string.format(
					"insufficient copies of '%s': need %d, have %d",
					cardId,
					count,
					if owned then owned.count else 0
				)
		end
	end

	-- Verify coin balance.
	if ownerCoins < offer.coins then
		return false, string.format("insufficient coins: need %d, have %d", offer.coins, ownerCoins)
	end

	return true, ""
end

return Trade
