local TestKit = require("./TestKit")
local Inventory = require("../src/shared/Logic/Inventory")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("Inventory.grant / has", function()
	it("creates a new stack at count 1", function()
		local cards = {}
		expect(Inventory.grant(cards, "x")).toBe(1)
		expect(cards.x.aura).toBe(0)
		expect(Inventory.has(cards, "x")).toBeTruthy()
	end)

	it("stacks duplicates", function()
		local cards = {}
		Inventory.grant(cards, "x")
		expect(Inventory.grant(cards, "x")).toBe(2)
		expect(Inventory.has(cards, "x", 2)).toBeTruthy()
		expect(Inventory.has(cards, "x", 3)).toBeFalsy()
	end)
end)

describe("Inventory.consume", function()
	it("fails when not enough copies", function()
		local cards = {}
		Inventory.grant(cards, "x")
		expect(Inventory.consume(cards, "x", 2)).toBeFalsy()
		expect(cards.x.count).toBe(1)
	end)

	it("removes the entry when it hits zero", function()
		local cards = {}
		Inventory.grant(cards, "x")
		expect(Inventory.consume(cards, "x", 1)).toBeTruthy()
		expect(cards.x).toBe(nil)
	end)
end)

describe("Inventory.convertDuplicates", function()
	it("sells surplus beyond keep and leaves keep", function()
		local cards = { x = { cardId = "x", count = 5, aura = 0 } }
		expect(Inventory.convertDuplicates(cards, "x", 10, 1)).toBe(40)
		expect(cards.x.count).toBe(1)
	end)

	it("returns 0 when nothing to sell", function()
		local cards = { x = { cardId = "x", count = 1, aura = 0 } }
		expect(Inventory.convertDuplicates(cards, "x", 10, 1)).toBe(0)
	end)
end)
