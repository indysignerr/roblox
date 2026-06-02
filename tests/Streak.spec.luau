local TestKit = require("./TestKit")
local Streak = require("../src/shared/Logic/Streak")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

describe("Streak.dayNumber", function()
	it("converts unix time with resetHour=0 to a day number", function()
		-- Day 0 starts at 0; day 1 starts at 86400.
		expect(Streak.dayNumber(0, 0)).toBe(0)
		expect(Streak.dayNumber(86399, 0)).toBe(0)
		expect(Streak.dayNumber(86400, 0)).toBe(1)
	end)

	it("shifts the boundary by resetHour hours", function()
		-- resetHour=6 means day resets at 06:00 UTC.
		-- 6*3600 = 21600; day 0 boundary is [0, 21600+86400).
		expect(Streak.dayNumber(21600, 6)).toBe(0)
		expect(Streak.dayNumber(21600 + 86400 - 1, 6)).toBe(0)
		expect(Streak.dayNumber(21600 + 86400, 6)).toBe(1)
	end)
end)

describe("Streak.update — same day no-op", function()
	it("returns unchanged streak and zero reward when today == lastClaimDay", function()
		local streak = { current = 3, lastClaimDay = 10 }
		local newStreak, reward, claimed = Streak.update(streak, 10)
		expect(claimed).toBeFalsy()
		expect(reward).toBe(0)
		expect(newStreak.current).toBe(3)
		expect(newStreak.lastClaimDay).toBe(10)
	end)
end)

describe("Streak.update — consecutive days", function()
	it("increments current and issues 50*day reward", function()
		local streak = { current = 1, lastClaimDay = 5 }
		local newStreak, reward, claimed = Streak.update(streak, 6)
		expect(claimed).toBeTruthy()
		expect(newStreak.current).toBe(2)
		expect(reward).toBe(100) -- 50 * 2
		expect(newStreak.lastClaimDay).toBe(6)
	end)

	it("increments across multiple consecutive days correctly", function()
		local streak = { current = 4, lastClaimDay = 20 }
		local newStreak, reward, claimed = Streak.update(streak, 21)
		expect(claimed).toBeTruthy()
		expect(newStreak.current).toBe(5)
		expect(reward).toBe(250) -- 50 * 5
	end)
end)

describe("Streak.update — gap resets to 1", function()
	it("resets current to 1 when a day is missed", function()
		local streak = { current = 5, lastClaimDay = 10 }
		local newStreak, reward, claimed = Streak.update(streak, 13)
		expect(claimed).toBeTruthy()
		expect(newStreak.current).toBe(1)
		expect(reward).toBe(50) -- 50 * 1
		expect(newStreak.lastClaimDay).toBe(13)
	end)

	it("resets when lastClaimDay is 0 (never claimed) and day > 1", function()
		local streak = { current = 0, lastClaimDay = 0 }
		local newStreak, reward, claimed = Streak.update(streak, 5)
		expect(claimed).toBeTruthy()
		expect(newStreak.current).toBe(1)
		expect(reward).toBe(50)
	end)
end)

describe("Streak.update — reward cap at day 7", function()
	it("caps reward at 50*7=350 on day 7", function()
		local streak = { current = 6, lastClaimDay = 6 }
		local newStreak, reward, claimed = Streak.update(streak, 7)
		expect(claimed).toBeTruthy()
		expect(newStreak.current).toBe(7)
		expect(reward).toBe(350) -- 50 * min(7, 7)
	end)

	it("stays capped at 350 beyond day 7", function()
		local streak = { current = 10, lastClaimDay = 20 }
		local newStreak, reward, claimed = Streak.update(streak, 21)
		expect(claimed).toBeTruthy()
		expect(newStreak.current).toBe(11)
		expect(reward).toBe(350) -- 50 * min(11, 7) = 50 * 7
	end)
end)
