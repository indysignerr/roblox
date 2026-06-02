--!strict
-- PURE inventory math over a cards map: { [cardId] = { cardId, count, aura } }.
-- No requires, no Roblox -> Lune-testable. All functions mutate the map in place
-- (the ProfileStore idiom) and return a plain result.

type OwnedCard = { cardId: string, count: number, aura: number }
type Cards = { [string]: OwnedCard }

local Inventory = {}

function Inventory.has(cards: Cards, cardId: string, n: number?): boolean
	local owned = cards[cardId]
	return owned ~= nil and owned.count >= (n or 1)
end

-- Grant one copy (stacks; duplicates raise count so fusion/trade have fodder).
-- Returns the new count.
function Inventory.grant(cards: Cards, cardId: string): number
	local owned = cards[cardId]
	if owned then
		owned.count += 1
	else
		owned = { cardId = cardId, count = 1, aura = 0 }
		cards[cardId] = owned
	end
	return owned.count
end

-- Remove n copies if available. Returns true on success; deletes the entry at 0.
function Inventory.consume(cards: Cards, cardId: string, n: number): boolean
	local owned = cards[cardId]
	if not owned or owned.count < n then
		return false
	end
	owned.count -= n
	if owned.count <= 0 then
		cards[cardId] = nil
	end
	return true
end

-- Anti-dupe: sell surplus copies beyond `keep` (default 1) at `perCopy` coins each.
-- Returns total coins gained.
function Inventory.convertDuplicates(
	cards: Cards,
	cardId: string,
	perCopy: number,
	keep: number?
): number
	local owned = cards[cardId]
	if not owned then
		return 0
	end
	local keepN = keep or 1
	local surplus = owned.count - keepN
	if surplus <= 0 then
		return 0
	end
	owned.count = keepN
	return perCopy * surplus
end

return Inventory
