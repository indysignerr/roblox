--!strict
-- PURE pack logic. No Roblox globals, no requires -> Lune-testable.
-- Config (weights, order, resetHour) must be injected by the caller.

local Packs = {}

-- Returns the integer "day number" for a given Unix timestamp.
-- Day 0 starts at `resetHour` * 3600 seconds from epoch.
function Packs.dayNumber(unixTime: number, resetHour: number): number
	return math.floor((unixTime - resetHour * 3600) / 86400)
end

-- Returns true when the player is allowed to claim today's daily pack.
-- `lastDailyPackDay` is the day number stored in the profile (0 = never claimed).
function Packs.canClaimDaily(lastDailyPackDay: number, today: number): boolean
	return today > lastDailyPackDay
end

-- Weighted rarity pick identical to RarityRoll.pick so Packs stays self-contained.
-- `weights` maps rarity -> weight, `order` gives stable iteration order,
-- `roll` is a number in [0, 1).
function Packs.rollRarity(weights: { [string]: number }, order: { string }, roll: number): string
	local total = 0
	for _, key in order do
		total += weights[key] or 0
	end

	if total <= 0 then
		return order[1]
	end

	local target = roll * total
	local acc = 0
	for _, key in order do
		acc += weights[key] or 0
		if target < acc then
			return key
		end
	end

	return order[#order]
end

-- Picks one element from `list` using `roll` ([0,1)).
-- Returns nil if the list is empty.
function Packs.pickFromList(list: { any }, roll: number): any
	if #list == 0 then
		return nil
	end
	local idx = math.clamp(math.floor(roll * #list) + 1, 1, #list)
	return list[idx]
end

return Packs
