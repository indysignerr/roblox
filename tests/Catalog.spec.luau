local TestKit = require("./TestKit")
local Catalog = require("../src/shared/Logic/Catalog")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

local function card(id: string, nation: string, rarity: string)
	return { id = id, name = id, nation = nation, rarity = rarity, basePower = 1, imageId = "" }
end

local sample = {
	card("a", "France", "Common"),
	card("b", "France", "Rare"),
	card("c", "Brésil", "Rare"),
}

describe("Catalog", function()
	it("get finds by id", function()
		expect(Catalog.get(sample, "b").nation).toBe("France")
	end)

	it("get returns nil for unknown id", function()
		expect(Catalog.get(sample, "zzz")).toBe(nil)
	end)

	it("index maps id -> def", function()
		local map = Catalog.index(sample)
		expect(map.c.nation).toBe("Brésil")
	end)

	it("byRarity filters", function()
		expect(#Catalog.byRarity(sample, "Rare")).toBe(2)
		expect(#Catalog.byRarity(sample, "Mythic")).toBe(0)
	end)

	it("byNation filters", function()
		expect(#Catalog.byNation(sample, "France")).toBe(2)
	end)

	it("nations returns uniques in order", function()
		expect(Catalog.nations(sample)).toEqual({ "France", "Brésil" })
	end)
end)
