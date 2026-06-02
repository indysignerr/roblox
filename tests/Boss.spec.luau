local TestKit = require("./TestKit")
local Boss = require("../src/shared/Logic/Boss")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("Boss.applyDamage", function()
	it("subtracts damage from hp", function()
		expect(Boss.applyDamage(1000, 250)).toBe(750)
	end)

	it("floors at 0 when damage exceeds hp", function()
		expect(Boss.applyDamage(100, 500)).toBe(0)
		expect(Boss.applyDamage(0, 100)).toBe(0)
	end)

	it("returns hp unchanged when damage is 0", function()
		expect(Boss.applyDamage(500, 0)).toBe(500)
	end)
end)

describe("Boss.isDead", function()
	it("returns true when hp is 0", function()
		expect(Boss.isDead(0)).toBeTruthy()
	end)

	it("returns true when hp is negative", function()
		expect(Boss.isDead(-1)).toBeTruthy()
	end)

	it("returns false when hp is above 0", function()
		expect(Boss.isDead(1)).toBeFalsy()
		expect(Boss.isDead(9999)).toBeFalsy()
	end)
end)

describe("Boss.splitReward", function()
	it("splits reward evenly across participants (floor)", function()
		-- 5000 / 3 = 1666 (floor)
		expect(Boss.splitReward(5000, 3)).toBe(1666)
	end)

	it("returns full reward for a single participant", function()
		expect(Boss.splitReward(5000, 1)).toBe(5000)
	end)

	it("guards against division by zero (0 treated as 1)", function()
		expect(Boss.splitReward(5000, 0)).toBe(5000)
	end)

	it("floors fractional splits", function()
		expect(Boss.splitReward(100, 3)).toBe(33)
	end)
end)
