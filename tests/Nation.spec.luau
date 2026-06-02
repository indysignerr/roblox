local TestKit = require("./TestKit")
local Nation = require("../src/shared/Logic/Nation")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

-- Helper: build a minimal catalog index { [id] = CardDef }.
local function makeCatalog(defs: { { id: string, basePower: number } }): { [string]: any }
	local index: { [string]: any } = {}
	for _, def in defs do
		index[def.id] = {
			id = def.id,
			basePower = def.basePower,
			name = "",
			nation = "",
			rarity = "Common",
			imageId = "",
		}
	end
	return index
end

describe("Nation.collectionValue", function()
	it("returns 0 for an empty cards map", function()
		local catalog = makeCatalog({ { id = "card_a", basePower = 10 } })
		expect(Nation.collectionValue({}, catalog)).toBe(0)
	end)

	it("sums basePower * count for each owned card", function()
		local catalog = makeCatalog({
			{ id = "card_a", basePower = 10 },
			{ id = "card_b", basePower = 20 },
		})
		local cards = {
			card_a = { cardId = "card_a", count = 3, aura = 0 },
			card_b = { cardId = "card_b", count = 2, aura = 0 },
		}
		-- 10*3 + 20*2 = 30 + 40 = 70
		expect(Nation.collectionValue(cards, catalog)).toBe(70)
	end)

	it("ignores owned cards not present in catalog", function()
		local catalog = makeCatalog({ { id = "card_a", basePower = 10 } })
		local cards = {
			card_a = { cardId = "card_a", count = 1, aura = 0 },
			unknown_card = { cardId = "unknown_card", count = 5, aura = 0 },
		}
		expect(Nation.collectionValue(cards, catalog)).toBe(10)
	end)

	it("handles count > 1 correctly (stacked duplicates)", function()
		local catalog = makeCatalog({ { id = "card_x", basePower = 50 } })
		local cards = {
			card_x = { cardId = "card_x", count = 4, aura = 0 },
		}
		expect(Nation.collectionValue(cards, catalog)).toBe(200)
	end)
end)

describe("Nation.score", function()
	it("combines collection value and wins with weights", function()
		local cfg = { collectionValueWeight = 0.5, winsWeight = 0.5 }
		-- 0.5 * 100 + 0.5 * 20 = 50 + 10 = 60
		expect(Nation.score(100, 20, cfg)).toBeCloseTo(60, 1e-9)
	end)

	it("respects unequal weights", function()
		local cfg = { collectionValueWeight = 0.8, winsWeight = 0.2 }
		-- 0.8 * 200 + 0.2 * 50 = 160 + 10 = 170
		expect(Nation.score(200, 50, cfg)).toBeCloseTo(170, 1e-9)
	end)

	it("returns 0 when both inputs are 0", function()
		local cfg = { collectionValueWeight = 0.5, winsWeight = 0.5 }
		expect(Nation.score(0, 0, cfg)).toBe(0)
	end)
end)
