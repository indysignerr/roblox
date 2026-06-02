--!strict
-- Pure social logic: emote validation, showcase ranking, spy gate.
-- No requires, no Roblox globals. Config is injected as arguments.

type EmoteDef = {
	id: string,
	label: string,
}

type CardDef = {
	id: string,
	name: string,
	nation: string,
	rarity: string,
	basePower: number,
	imageId: string,
}

type OwnedCard = {
	cardId: string,
	count: number,
	aura: number,
}

local Social = {}

-- Returns true if emoteId exists in the emote list.
function Social.isValidEmote(emotes: { EmoteDef }, emoteId: string): boolean
	for _, emote in emotes do
		if emote.id == emoteId then
			return true
		end
	end
	return false
end

-- Returns up to n owned card ids sorted by basePower DESC.
-- Tie-break: card id ASC (lexicographic) for determinism.
-- `ownedCards` is the profile.cards map { [cardId]: OwnedCard }.
-- `catalog` is the id -> CardDef index (from Catalog.index).
function Social.topCards(
	ownedCards: { [string]: OwnedCard },
	catalog: { [string]: CardDef },
	n: number
): { string }
	-- Collect all owned card ids that exist in the catalog.
	local owned: { string } = {}
	for cardId in ownedCards do
		if catalog[cardId] then
			table.insert(owned, cardId)
		end
	end

	-- Sort by basePower DESC, id ASC on ties.
	table.sort(owned, function(a: string, b: string): boolean
		local pa = catalog[a].basePower
		local pb = catalog[b].basePower
		if pa ~= pb then
			return pa > pb
		end
		return a < b
	end)

	-- Truncate to n.
	local result: { string } = {}
	for i = 1, math.min(n, #owned) do
		table.insert(result, owned[i])
	end
	return result
end

-- Robux gate placeholder. Returns hasPaid directly.
-- Real MarketplaceService wiring is a follow-up integration task.
function Social.canSpy(hasPaid: boolean): boolean
	return hasPaid
end

return Social
