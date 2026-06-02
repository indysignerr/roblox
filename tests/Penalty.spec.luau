local TestKit = require("./TestKit")
local Penalty = require("../src/shared/Logic/Penalty")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("Penalty.resolve", function()
	it("scores a goal when shotDir differs from keeperDir", function()
		expect(Penalty.resolve(1, 2)).toBeTruthy()
		expect(Penalty.resolve(3, 5)).toBeTruthy()
		expect(Penalty.resolve(5, 1)).toBeTruthy()
	end)

	it("keeper saves when directions match exactly", function()
		expect(Penalty.resolve(1, 1)).toBeFalsy()
		expect(Penalty.resolve(3, 3)).toBeFalsy()
		expect(Penalty.resolve(5, 5)).toBeFalsy()
	end)
end)

describe("Penalty.reward", function()
	local cfg = { goalReward = 100, missReward = 10 }

	it("returns goalReward when isGoal is true", function()
		expect(Penalty.reward(true, cfg)).toBe(100)
	end)

	it("returns missReward when isGoal is false", function()
		expect(Penalty.reward(false, cfg)).toBe(10)
	end)
end)
