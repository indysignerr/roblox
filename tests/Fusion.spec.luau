local TestKit = require("./TestKit")
local Fusion = require("../src/shared/Logic/Fusion")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

-- Helper: build a minimal CardDef.
local function def(id: string, rarity: string, basePower: number)
	return {
		id = id,
		name = id,
		nation = "TestNation",
		rarity = rarity,
		basePower = basePower,
		imageId = "",
	}
end

-- Helper: build an OwnedCard entry.
local function owned(cardId: string, count: number)
	return { cardId = cardId, count = count, aura = 0 }
end

-- Small fake catalog (id -> CardDef) and cards map ({ [id] = OwnedCard }).
local catalog = {
	rare_a = def("rare_a", "Rare", 30),
	rare_b = def("rare_b", "Rare", 25),
	rare_c = def("rare_c", "Rare", 35),
	common_x = def("common_x", "Common", 10),
	epic_e = def("epic_e", "Epic", 50),
}

describe("Fusion.collectInputs", function()
	it("returns nil when not enough copies owned", function()
		local cards = {
			rare_a = owned("rare_a", 2),
			rare_b = owned("rare_b", 2),
		}
		-- Only 4 total Rare copies, need 5.
		expect(Fusion.collectInputs(cards, catalog, "Rare", 5)).toBeFalsy()
	end)

	it("returns nil when no matching rarity at all", function()
		local cards = {
			common_x = owned("common_x", 10),
		}
		expect(Fusion.collectInputs(cards, catalog, "Rare", 5)).toBeFalsy()
	end)

	it("returns nil when exactly one short", function()
		local cards = {
			rare_a = owned("rare_a", 4),
		}
		expect(Fusion.collectInputs(cards, catalog, "Rare", 5)).toBeFalsy()
	end)

	it("returns exactly inputCount ids when enough copies owned", function()
		local cards = {
			rare_a = owned("rare_a", 3),
			rare_b = owned("rare_b", 3),
		}
		local result = Fusion.collectInputs(cards, catalog, "Rare", 5)
		expect(result).toBeTruthy()
		if result then
			expect(#result).toBe(5)
		end
	end)

	it("prefers lowest basePower first (rare_b=25 before rare_a=30)", function()
		local cards = {
			rare_a = owned("rare_a", 3),
			rare_b = owned("rare_b", 3),
		}
		local result = Fusion.collectInputs(cards, catalog, "Rare", 5)
		expect(result).toBeTruthy()
		if result then
			-- rare_b (25) should come before rare_a (30).
			-- First 3 entries should be rare_b, remaining 2 rare_a.
			expect(result[1]).toBe("rare_b")
			expect(result[2]).toBe("rare_b")
			expect(result[3]).toBe("rare_b")
			expect(result[4]).toBe("rare_a")
			expect(result[5]).toBe("rare_a")
		end
	end)

	it("honors count > 1: uses multiple copies of the same card", function()
		-- Only rare_a with 5 copies; should return 5x rare_a.
		local cards = {
			rare_a = owned("rare_a", 5),
		}
		local result = Fusion.collectInputs(cards, catalog, "Rare", 5)
		expect(result).toBeTruthy()
		if result then
			expect(#result).toBe(5)
			for _, id in result do
				expect(id).toBe("rare_a")
			end
		end
	end)

	it("ignores non-matching rarity cards", function()
		local cards = {
			rare_a = owned("rare_a", 3),
			rare_b = owned("rare_b", 3),
			common_x = owned("common_x", 99),
			epic_e = owned("epic_e", 99),
		}
		local result = Fusion.collectInputs(cards, catalog, "Rare", 5)
		expect(result).toBeTruthy()
		if result then
			-- All returned ids must be Rare.
			for _, id in result do
				expect(catalog[id].rarity).toBe("Rare")
			end
		end
	end)
end)

describe("Fusion.resolve", function()
	it("returns true when roll is just below successRate", function()
		expect(Fusion.resolve(0.7999, 0.80)).toBeTruthy()
	end)

	it("returns false when roll equals successRate", function()
		expect(Fusion.resolve(0.80, 0.80)).toBeFalsy()
	end)

	it("returns false when roll is above successRate", function()
		expect(Fusion.resolve(0.9, 0.80)).toBeFalsy()
	end)

	it("returns true at roll = 0", function()
		expect(Fusion.resolve(0, 0.80)).toBeTruthy()
	end)

	it("returns false at roll = 1 (edge)", function()
		expect(Fusion.resolve(1, 0.80)).toBeFalsy()
	end)
end)

describe("Fusion.pickOutput", function()
	it("returns nil for empty list", function()
		expect(Fusion.pickOutput({}, 0.5)).toBeFalsy()
	end)

	it("returns the only element for a list of one", function()
		expect(Fusion.pickOutput({ "epic_e" }, 0.0)).toBe("epic_e")
		expect(Fusion.pickOutput({ "epic_e" }, 0.99)).toBe("epic_e")
	end)

	it("returns the first element at roll = 0", function()
		local ids = { "alpha", "beta", "gamma" }
		expect(Fusion.pickOutput(ids, 0.0)).toBe("alpha")
	end)

	it("returns the last element at roll just below 1", function()
		local ids = { "alpha", "beta", "gamma" }
		-- floor(0.999 * 3) + 1 = floor(2.997) + 1 = 2 + 1 = 3 -> "gamma"
		expect(Fusion.pickOutput(ids, 0.999)).toBe("gamma")
	end)

	it("distributes across all slots correctly", function()
		local ids = { "alpha", "beta", "gamma" }
		-- roll = 0.5 -> floor(0.5*3)+1 = floor(1.5)+1 = 1+1 = 2 -> "beta"
		expect(Fusion.pickOutput(ids, 0.5)).toBe("beta")
	end)
end)
