local TestKit = require("./TestKit")
local Shield = require("../src/shared/Logic/Shield")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("Shield.isActive", function()
	it("returns false when shield.active is false", function()
		local s = { active = false, expiresAt = 9999 }
		expect(Shield.isActive(s, 0)).toBeFalsy()
	end)

	it("returns false when active but now >= expiresAt (expired)", function()
		local s = { active = true, expiresAt = 100 }
		expect(Shield.isActive(s, 100)).toBeFalsy()
		expect(Shield.isActive(s, 200)).toBeFalsy()
	end)

	it("returns true when active and now < expiresAt", function()
		local s = { active = true, expiresAt = 1000 }
		expect(Shield.isActive(s, 999)).toBeTruthy()
		expect(Shield.isActive(s, 0)).toBeTruthy()
	end)
end)

describe("Shield.activate", function()
	it("returns an active shield expiring at now + duration", function()
		local result = Shield.activate(500, 600)
		expect(result.active).toBeTruthy()
		expect(result.expiresAt).toBe(1100)
	end)

	it("works with now = 0", function()
		local result = Shield.activate(0, 300)
		expect(result.active).toBeTruthy()
		expect(result.expiresAt).toBe(300)
	end)
end)

describe("Shield.remaining", function()
	it("returns 0 when shield is inactive", function()
		local s = { active = false, expiresAt = 9999 }
		expect(Shield.remaining(s, 0)).toBe(0)
	end)

	it("returns 0 when active but already expired", function()
		local s = { active = true, expiresAt = 100 }
		expect(Shield.remaining(s, 100)).toBe(0)
		expect(Shield.remaining(s, 500)).toBe(0)
	end)

	it("returns the positive seconds left when active and unexpired", function()
		local s = { active = true, expiresAt = 1000 }
		expect(Shield.remaining(s, 400)).toBe(600)
		expect(Shield.remaining(s, 999)).toBe(1)
	end)
end)
