local TestKit = require("./TestKit")
local Steal = require("../src/shared/Logic/Steal")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("Steal.canSteal", function()
	it("returns false/shielded when victim has an active shield", function()
		local ok, reason = Steal.canSteal(true, { "card_a", "card_b" })
		expect(ok).toBeFalsy()
		expect(reason).toBe("shielded")
	end)

	it("returns false/empty when victim has no cards (and no shield)", function()
		local ok, reason = Steal.canSteal(false, {})
		expect(ok).toBeFalsy()
		expect(reason).toBe("empty")
	end)

	it("returns true/ok when unshielded victim has at least one card", function()
		local ok, reason = Steal.canSteal(false, { "card_a" })
		expect(ok).toBeTruthy()
		expect(reason).toBe("ok")
	end)

	it("shield check takes priority over empty check", function()
		-- Shielded AND empty: should still report 'shielded'.
		local ok, reason = Steal.canSteal(true, {})
		expect(ok).toBeFalsy()
		expect(reason).toBe("shielded")
	end)
end)

describe("Steal.pickTarget", function()
	it("returns nil for an empty list", function()
		expect(Steal.pickTarget({}, 0.5)).toBe(nil)
	end)

	it("returns the only element regardless of roll", function()
		local ids = { "solo" }
		expect(Steal.pickTarget(ids, 0)).toBe("solo")
		expect(Steal.pickTarget(ids, 0.99)).toBe("solo")
	end)

	it("picks the first element when roll is 0", function()
		local ids = { "first", "second", "third" }
		expect(Steal.pickTarget(ids, 0)).toBe("first")
	end)

	it("picks the last element when roll is at the upper boundary", function()
		local ids = { "first", "second", "third" }
		-- roll = 1 - epsilon -> floor(0.999 * 3) + 1 = floor(2.997) + 1 = 2 + 1 = 3
		expect(Steal.pickTarget(ids, 0.999)).toBe("third")
	end)

	it("distributes across list (middle index)", function()
		local ids = { "a", "b", "c", "d" }
		-- roll = 0.5 -> floor(0.5 * 4) + 1 = floor(2) + 1 = 3 -> "c"
		expect(Steal.pickTarget(ids, 0.5)).toBe("c")
	end)
end)
