local TestKit = require("./TestKit")
local RarityRoll = require("../src/shared/Logic/RarityRoll")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("RarityRoll.pick", function()
	local weights = { Common = 60, Rare = 10, Legendary = 0.1 }
	local order = { "Common", "Rare", "Legendary" }

	it("returns the first bucket at roll 0", function()
		expect(RarityRoll.pick(weights, order, 0)).toBe("Common")
	end)

	it("returns the last bucket near roll 1", function()
		expect(RarityRoll.pick(weights, order, 0.999)).toBe("Legendary")
	end)

	it("respects bucket boundaries", function()
		local total = 70.1
		expect(RarityRoll.pick(weights, order, 59 / total)).toBe("Common")
		expect(RarityRoll.pick(weights, order, 65 / total)).toBe("Rare")
	end)

	it("falls back to the first key when all weights are zero", function()
		expect(RarityRoll.pick({ A = 0, B = 0 }, { "A", "B" }, 0.5)).toBe("A")
	end)
end)
