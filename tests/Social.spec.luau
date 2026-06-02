local TestKit = require("./TestKit")
local Social = require("../src/shared/Logic/Social")
local EmoteConfig = require("../src/shared/Config/EmoteConfig")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

-- Minimal emote list for isolation tests.
local sampleEmotes = {
	{ id = "mega_celebration", label = "Méga Célébration" },
	{ id = "robot_dance", label = "Danse Robotique" },
	{ id = "crown_flex", label = "Flex Couronne" },
}

-- Minimal catalog index for topCards tests.
local sampleCatalog = {
	card_a = {
		id = "card_a",
		name = "A",
		nation = "France",
		rarity = "Common",
		basePower = 10,
		imageId = "",
	},
	card_b = {
		id = "card_b",
		name = "B",
		nation = "France",
		rarity = "Uncommon",
		basePower = 30,
		imageId = "",
	},
	card_c = {
		id = "card_c",
		name = "C",
		nation = "Brésil",
		rarity = "Rare",
		basePower = 50,
		imageId = "",
	},
	card_d = {
		id = "card_d",
		name = "D",
		nation = "Espagne",
		rarity = "Epic",
		basePower = 50,
		imageId = "",
	},
	card_e = {
		id = "card_e",
		name = "E",
		nation = "Portugal",
		rarity = "Legendary",
		basePower = 75,
		imageId = "",
	},
}

-- Helper to build an ownedCards map from a list of ids.
local function ownedMap(
	ids: { string }
): { [string]: { cardId: string, count: number, aura: number } }
	local map = {}
	for _, id in ids do
		map[id] = { cardId = id, count = 1, aura = 0 }
	end
	return map
end

describe("Social.isValidEmote", function()
	it("returns true for a known emote id", function()
		expect(Social.isValidEmote(sampleEmotes, "mega_celebration")).toBeTruthy()
	end)

	it("returns true for another known emote id", function()
		expect(Social.isValidEmote(sampleEmotes, "robot_dance")).toBeTruthy()
	end)

	it("returns false for an unknown emote id", function()
		expect(Social.isValidEmote(sampleEmotes, "unknown_emote")).toBeFalsy()
	end)

	it("returns false for an empty string", function()
		expect(Social.isValidEmote(sampleEmotes, "")).toBeFalsy()
	end)

	it("validates all emotes from the real EmoteConfig", function()
		for _, emote in EmoteConfig do
			expect(Social.isValidEmote(EmoteConfig, emote.id)).toBeTruthy()
		end
	end)
end)

describe("Social.topCards", function()
	it("returns empty list when no cards owned", function()
		expect(Social.topCards({}, sampleCatalog, 5)).toEqual({})
	end)

	it("returns cards sorted by basePower DESC", function()
		local owned = ownedMap({ "card_a", "card_b", "card_c" })
		local result = Social.topCards(owned, sampleCatalog, 10)
		-- card_c (50) > card_b (30) > card_a (10)
		expect(result[1]).toBe("card_c")
		expect(result[2]).toBe("card_b")
		expect(result[3]).toBe("card_a")
	end)

	it("respects the n limit", function()
		local owned = ownedMap({ "card_a", "card_b", "card_c", "card_d", "card_e" })
		local result = Social.topCards(owned, sampleCatalog, 3)
		expect(#result).toBe(3)
	end)

	it("n larger than owned count returns all", function()
		local owned = ownedMap({ "card_a", "card_b" })
		local result = Social.topCards(owned, sampleCatalog, 5)
		expect(#result).toBe(2)
	end)

	it("tie-break by id ASC is deterministic", function()
		-- card_c and card_d both have basePower = 50; card_c < card_d lexicographically.
		local owned = ownedMap({ "card_c", "card_d" })
		local result = Social.topCards(owned, sampleCatalog, 2)
		expect(result[1]).toBe("card_c")
		expect(result[2]).toBe("card_d")
	end)

	it("skips card ids absent from catalog", function()
		local owned = ownedMap({ "card_a", "not_in_catalog" })
		local result = Social.topCards(owned, sampleCatalog, 5)
		expect(#result).toBe(1)
		expect(result[1]).toBe("card_a")
	end)
end)

describe("Social.canSpy", function()
	it("returns true when hasPaid is true", function()
		expect(Social.canSpy(true)).toBeTruthy()
	end)

	it("returns false when hasPaid is false", function()
		expect(Social.canSpy(false)).toBeFalsy()
	end)
end)
