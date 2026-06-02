--!strict
-- PURE card-catalogue helpers. No requires -> Lune-testable. Pass the CardDef list
-- (e.g. Config.Cards) into every function so this module never depends on Roblox.

type CardDef = {
	id: string,
	name: string,
	nation: string,
	rarity: string,
	basePower: number,
	imageId: string,
}

local Catalog = {}

-- Build an id -> CardDef map for O(1) lookups.
function Catalog.index(cards: { CardDef }): { [string]: CardDef }
	local map: { [string]: CardDef } = {}
	for _, card in cards do
		map[card.id] = card
	end
	return map
end

function Catalog.get(cards: { CardDef }, id: string): CardDef?
	for _, card in cards do
		if card.id == id then
			return card
		end
	end
	return nil
end

function Catalog.byRarity(cards: { CardDef }, rarity: string): { CardDef }
	local out: { CardDef } = {}
	for _, card in cards do
		if card.rarity == rarity then
			table.insert(out, card)
		end
	end
	return out
end

function Catalog.byNation(cards: { CardDef }, nation: string): { CardDef }
	local out: { CardDef } = {}
	for _, card in cards do
		if card.nation == nation then
			table.insert(out, card)
		end
	end
	return out
end

-- Unique nations in catalogue order.
function Catalog.nations(cards: { CardDef }): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, card in cards do
		if not seen[card.nation] then
			seen[card.nation] = true
			table.insert(out, card.nation)
		end
	end
	return out
end

return Catalog
