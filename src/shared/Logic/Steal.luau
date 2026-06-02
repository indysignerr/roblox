--!strict
-- PURE steal logic. No requires, no Roblox globals -> Lune-testable.

local Steal = {}

-- Check whether a steal attempt is valid given the victim's current state.
-- Returns (canProceed: boolean, reason: string).
-- reason is "shielded" | "empty" | "ok".
function Steal.canSteal(
	victimShieldActive: boolean,
	victimOwnedCardIds: { string }
): (boolean, string)
	if victimShieldActive then
		return false, "shielded"
	end
	if #victimOwnedCardIds == 0 then
		return false, "empty"
	end
	return true, "ok"
end

-- Pick a card id from the victim's card list using a normalised roll in [0, 1).
-- Distributes uniformly across the list. Returns nil if the list is empty.
function Steal.pickTarget(ownedCardIds: { string }, roll: number): string?
	local n = #ownedCardIds
	if n == 0 then
		return nil
	end
	local idx = math.clamp(math.floor(roll * n) + 1, 1, n)
	return ownedCardIds[idx]
end

return Steal
