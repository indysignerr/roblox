--!strict
-- PURE market math. No requires, no Roblox -> Lune-testable.
-- Pass marketTax table (Rarities.marketTax) into each function.

local Market = {}

-- Returns the tax rate for a given rarity, or 0 if not found.
function Market.taxRateFor(rarity: string, marketTax: { [string]: number }): number
	return marketTax[rarity] or 0
end

-- Net coins a seller receives after tax is deducted from the sale price.
-- Floors the result so only whole coins are paid out.
function Market.netProceeds(price: number, taxRate: number): number
	return math.floor(price * (1 - taxRate))
end

return Market
