--!strict
-- Pure fusion logic. No requires, no Roblox globals -> Lune-testable.
-- Config is injected as arguments.

type CardDef = {
	id: string,
	name: string,
	nation: string,
	rarity: string,
	basePower: number,
	imageId: string,
}

type OwnedCard = { cardId: string, count: number, aura: number }
type CardsMap = { [string]: OwnedCard }
type CatalogMap = { [string]: CardDef }

local Fusion = {}

-- Returns a flat list of exactly `inputCount` card ids drawn from owned cards
-- whose catalog[id].rarity == inputRarity. Repeats by owned count, sorting
-- candidates by lowest basePower first (so we burn weakest copies first).
-- Returns nil if fewer than `inputCount` total copies are owned with that rarity.
function Fusion.collectInputs(
	cards: CardsMap,
	catalog: CatalogMap,
	inputRarity: string,
	inputCount: number
): { string }?
	-- Gather all candidate cards matching rarity, paired with their basePower.
	type Candidate = { id: string, basePower: number, count: number }
	local candidates: { Candidate } = {}

	for cardId, owned in cards do
		local def = catalog[cardId]
		if def and def.rarity == inputRarity and owned.count > 0 then
			table.insert(candidates, {
				id = cardId,
				basePower = def.basePower,
				count = owned.count,
			})
		end
	end

	-- Sort by basePower ascending (lowest first) for deterministic preference.
	table.sort(candidates, function(a, b)
		if a.basePower == b.basePower then
			return a.id < b.id
		end
		return a.basePower < b.basePower
	end)

	-- Expand candidates into a flat list (up to `inputCount` total slots).
	local result: { string } = {}
	for _, candidate in candidates do
		for _ = 1, candidate.count do
			if #result >= inputCount then
				break
			end
			table.insert(result, candidate.id)
		end
		if #result >= inputCount then
			break
		end
	end

	if #result < inputCount then
		return nil
	end

	return result
end

-- Returns true if `roll` is strictly less than `successRate`.
function Fusion.resolve(roll: number, successRate: number): boolean
	return roll < successRate
end

-- Picks a card id from `outputCardIds` based on a uniform roll [0, 1).
-- Uses: index = clamp(floor(roll * #list) + 1, 1, #list).
-- Returns nil if the list is empty.
function Fusion.pickOutput(outputCardIds: { string }, roll: number): string?
	if #outputCardIds == 0 then
		return nil
	end
	local index = math.floor(roll * #outputCardIds) + 1
	if index < 1 then
		index = 1
	elseif index > #outputCardIds then
		index = #outputCardIds
	end
	return outputCardIds[index]
end

return Fusion
