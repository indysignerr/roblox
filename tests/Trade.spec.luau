local TestKit = require("./TestKit")
local Trade = require("../src/shared/Logic/Trade")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

-- Helpers to build minimal cards maps.
local function makeCards(
	entries: { { id: string, count: number } }
): { [string]: { cardId: string, count: number, aura: number } }
	local cards: { [string]: { cardId: string, count: number, aura: number } } = {}
	for _, e in entries do
		cards[e.id] = { cardId = e.id, count = e.count, aura = 0 }
	end
	return cards
end

describe("Trade.validateOffer", function()
	it("ok when owner has exactly what is needed", function()
		local cards = makeCards({ { id = "card_a", count = 1 } })
		local ok, reason = Trade.validateOffer(cards, 100, { cardIds = { "card_a" }, coins = 50 })
		expect(ok).toBeTruthy()
		expect(reason).toBe("")
	end)

	it("ok when offering coins only (no cards)", function()
		local cards = makeCards({})
		local ok, _ = Trade.validateOffer(cards, 200, { cardIds = {}, coins = 200 })
		expect(ok).toBeTruthy()
	end)

	it("ok when offering cards only (no coins)", function()
		local cards = makeCards({ { id = "card_b", count = 3 } })
		local ok, _ = Trade.validateOffer(cards, 0, { cardIds = { "card_b" }, coins = 0 })
		expect(ok).toBeTruthy()
	end)

	it("fails when card is not owned at all", function()
		local cards = makeCards({})
		local ok, reason =
			Trade.validateOffer(cards, 500, { cardIds = { "card_missing" }, coins = 0 })
		expect(ok).toBeFalsy()
		expect(reason ~= "").toBeTruthy()
	end)

	it("fails when owner has fewer copies than offered", function()
		-- Owner has 1 copy but offer lists it twice (duplicate entries).
		local cards = makeCards({ { id = "card_c", count = 1 } })
		local ok, _ = Trade.validateOffer(cards, 0, { cardIds = { "card_c", "card_c" }, coins = 0 })
		expect(ok).toBeFalsy()
	end)

	it("ok when owner has exactly enough duplicate copies", function()
		-- Owner has 2 copies and offer lists the card twice.
		local cards = makeCards({ { id = "card_d", count = 2 } })
		local ok, _ = Trade.validateOffer(cards, 0, { cardIds = { "card_d", "card_d" }, coins = 0 })
		expect(ok).toBeTruthy()
	end)

	it("fails when coins are insufficient", function()
		local cards = makeCards({ { id = "card_e", count = 1 } })
		local ok, reason = Trade.validateOffer(cards, 10, { cardIds = {}, coins = 50 })
		expect(ok).toBeFalsy()
		expect(reason ~= "").toBeTruthy()
	end)

	it("fails when coins are exactly zero but offer wants some", function()
		local cards = makeCards({})
		local ok, _ = Trade.validateOffer(cards, 0, { cardIds = {}, coins = 1 })
		expect(ok).toBeFalsy()
	end)

	it("ok when owner has more than enough of everything", function()
		local cards = makeCards({
			{ id = "card_f", count = 5 },
			{ id = "card_g", count = 3 },
		})
		local ok, _ = Trade.validateOffer(cards, 1000, {
			cardIds = { "card_f", "card_f", "card_g" },
			coins = 500,
		})
		expect(ok).toBeTruthy()
	end)

	it("fails when one of several cards is missing", function()
		local cards = makeCards({ { id = "card_h", count = 2 } })
		local ok, _ = Trade.validateOffer(cards, 100, {
			cardIds = { "card_h", "card_not_there" },
			coins = 0,
		})
		expect(ok).toBeFalsy()
	end)
end)
