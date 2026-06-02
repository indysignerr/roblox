--!strict
-- PURE logic. No Roblox globals, no requires -> import directly under Lune for tests.
-- Config (weights/order) is injected by the caller (e.g. PackService).

local RarityRoll = {}

-- Weighted pick. `order` lists keys in a stable order; `weights` maps key -> weight.
-- `roll` is a number in [0, 1) (e.g. math.random()). Returns the chosen key.
function RarityRoll.pick(weights: { [string]: number }, order: { string }, roll: number): string
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

return RarityRoll
