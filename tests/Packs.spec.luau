local TestKit = require("./TestKit")
local Packs = require("../src/shared/Logic/Packs")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

-- ----------------------------------------------------------------
describe("Packs.dayNumber", function()
	it("returns 0 for timestamp at exactly the reset epoch", function()
		-- resetHour=0 => epoch start is 0; time=0 => day 0
		expect(Packs.dayNumber(0, 0)).toBe(0)
	end)

	it("advances by 1 after 86400 seconds", function()
		expect(Packs.dayNumber(86400, 0)).toBe(1)
	end)

	it("honours a non-zero resetHour", function()
		-- resetHour=6 shifts epoch by 6*3600=21600; time=21600 => day 0
		expect(Packs.dayNumber(21600, 6)).toBe(0)
		-- time=21600+86400 => day 1
		expect(Packs.dayNumber(21600 + 86400, 6)).toBe(1)
	end)

	it("floors (does not round up mid-day)", function()
		-- 1.5 days but resetHour=0 => still day 1
		expect(Packs.dayNumber(math.floor(86400 * 1.5), 0)).toBe(1)
	end)
end)

-- ----------------------------------------------------------------
describe("Packs.canClaimDaily", function()
	it("allows claim when today > lastDailyPackDay", function()
		expect(Packs.canClaimDaily(0, 1)).toBeTruthy()
	end)

	it("denies claim when today == lastDailyPackDay (already claimed)", function()
		expect(Packs.canClaimDaily(5, 5)).toBeFalsy()
	end)

	it("denies claim when today < lastDailyPackDay (should not happen but safe)", function()
		expect(Packs.canClaimDaily(10, 9)).toBeFalsy()
	end)
end)

-- ----------------------------------------------------------------
describe("Packs.rollRarity", function()
	local weights =
		{ Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Mythic = 0.1 }
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

	it("returns Common at roll 0 (first bucket)", function()
		expect(Packs.rollRarity(weights, order, 0)).toBe("Common")
	end)

	it("returns Mythic near roll 0.999 (last bucket)", function()
		expect(Packs.rollRarity(weights, order, 0.999)).toBe("Mythic")
	end)

	it("returns first element when all weights are 0", function()
		local zeroWeights = { A = 0, B = 0, C = 0 }
		local zeroOrder = { "A", "B", "C" }
		expect(Packs.rollRarity(zeroWeights, zeroOrder, 0.5)).toBe("A")
	end)

	it("respects bucket boundaries mid-distribution", function()
		-- total = 100; Common occupies [0, 60), Uncommon [60, 85)
		local total = 60 + 25 + 10 + 4 + 0.9 + 0.1 -- = 100
		-- roll at 59/100 = 0.59 -> inside Common bucket
		expect(Packs.rollRarity(weights, order, 59 / total)).toBe("Common")
		-- roll at 65/100 = 0.65 -> inside Uncommon bucket
		expect(Packs.rollRarity(weights, order, 65 / total)).toBe("Uncommon")
		-- roll at 88/100 = 0.88 -> inside Rare bucket
		expect(Packs.rollRarity(weights, order, 88 / total)).toBe("Rare")
	end)
end)

-- ----------------------------------------------------------------
describe("Packs.pickFromList", function()
	it("returns nil for an empty list", function()
		expect(Packs.pickFromList({}, 0.5)).toBeFalsy()
	end)

	it("returns the only element for a single-item list regardless of roll", function()
		expect(Packs.pickFromList({ "sole" }, 0)).toBe("sole")
		expect(Packs.pickFromList({ "sole" }, 0.999)).toBe("sole")
	end)

	it("returns the first element at roll 0", function()
		expect(Packs.pickFromList({ "first", "second", "third" }, 0)).toBe("first")
	end)

	it("returns the last element at roll near 1", function()
		expect(Packs.pickFromList({ "first", "second", "third" }, 0.999)).toBe("third")
	end)

	it("clamps so roll exactly 1 still returns the last element", function()
		-- roll=1 => floor(1*3)+1 = 4, clamped to 3
		expect(Packs.pickFromList({ "a", "b", "c" }, 1)).toBe("c")
	end)

	it("distributes across list with mid roll", function()
		-- roll=0.5, list size=4 => floor(0.5*4)+1 = 3 => "third"
		local list = { "one", "two", "three", "four" }
		expect(Packs.pickFromList(list, 0.5)).toBe("three")
	end)
end)
