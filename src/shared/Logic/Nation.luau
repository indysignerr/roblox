--!strict
-- Pure nation-score logic. No requires, no Roblox globals -> Lune-testable.

type OwnedCard = {
	cardId: string,
	count: number,
	aura: number,
}

type CardDef = {
	id: string,
	name: string,
	nation: string,
	rarity: string,
	basePower: number,
	imageId: string,
}

type NationScoreCfg = {
	collectionValueWeight: number,
	winsWeight: number,
}

local Nation = {}

-- Compute the total collection value for a player's cards.
-- catalog: id -> CardDef map (from Catalog.index(Cards)).
-- Value = sum of basePower * count for every owned card present in catalog.
function Nation.collectionValue(
	cards: { [string]: OwnedCard },
	catalog: { [string]: CardDef }
): number
	local total = 0
	for cardId, owned in cards do
		local def = catalog[cardId]
		if def then
			total += def.basePower * owned.count
		end
	end
	return total
end

-- Compute the nation leaderboard score for a player.
-- score = collectionValueWeight * collectionValue + winsWeight * wins
function Nation.score(collectionValue: number, wins: number, cfg: NationScoreCfg): number
	return cfg.collectionValueWeight * collectionValue + cfg.winsWeight * wins
end

return Nation
