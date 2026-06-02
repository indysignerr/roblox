local TestKit = require("./TestKit")
local Market = require("../src/shared/Logic/Market")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

local sampleTax = {
	Common = 0.05,
	Uncommon = 0.07,
	Rare = 0.10,
	Epic = 0.15,
	Legendary = 0.20,
	Mythic = 0.25,
}

describe("Market.taxRateFor", function()
	it("returns the correct rate for each rarity", function()
		expect(Market.taxRateFor("Common", sampleTax)).toBe(0.05)
		expect(Market.taxRateFor("Uncommon", sampleTax)).toBe(0.07)
		expect(Market.taxRateFor("Rare", sampleTax)).toBe(0.10)
		expect(Market.taxRateFor("Epic", sampleTax)).toBe(0.15)
		expect(Market.taxRateFor("Legendary", sampleTax)).toBe(0.20)
		expect(Market.taxRateFor("Mythic", sampleTax)).toBe(0.25)
	end)

	it("returns 0 for an unknown rarity", function()
		expect(Market.taxRateFor("Nonexistent", sampleTax)).toBe(0)
	end)
end)

describe("Market.netProceeds", function()
	it("price 100 Rare (10% tax) -> 90", function()
		local tax = Market.taxRateFor("Rare", sampleTax)
		expect(Market.netProceeds(100, tax)).toBe(90)
	end)

	it("price 100 Common (5% tax) -> 95", function()
		local tax = Market.taxRateFor("Common", sampleTax)
		expect(Market.netProceeds(100, tax)).toBe(95)
	end)

	it("price 100 Mythic (25% tax) -> 75", function()
		local tax = Market.taxRateFor("Mythic", sampleTax)
		expect(Market.netProceeds(100, tax)).toBe(75)
	end)

	it("floors fractional proceeds", function()
		-- price 101, 10% tax -> 90.9 -> floors to 90
		expect(Market.netProceeds(101, 0.10)).toBe(90)
	end)

	it("zero tax -> full price returned", function()
		expect(Market.netProceeds(500, 0)).toBe(500)
	end)
end)
