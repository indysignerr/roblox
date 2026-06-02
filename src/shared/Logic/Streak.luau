--!strict
-- Pure streak logic. No requires, no Roblox globals -> Lune-testable.

type StreakState = {
	current: number,
	lastClaimDay: number,
}

local Streak = {}

-- Convert a Unix timestamp to a day number (days since epoch, adjusted for resetHour).
-- resetHour: the hour of day (0-23) at which the day resets, in UTC.
function Streak.dayNumber(unixTime: number, resetHour: number): number
	return math.floor((unixTime - resetHour * 3600) / 86400)
end

-- Attempt to claim the daily streak reward.
-- Returns (newStreak, reward, claimed):
--   - If today == lastClaimDay: already claimed -> no change, reward 0, claimed false.
--   - If today == lastClaimDay + 1: consecutive day -> current + 1, claimed true.
--   - Otherwise: gap or first claim -> current resets to 1, claimed true.
-- Reward = 50 * min(newCurrent, 7), so it caps at 350 on day 7+.
function Streak.update(streak: StreakState, today: number): (StreakState, number, boolean)
	if today == streak.lastClaimDay then
		-- Already claimed today; return a copy unchanged.
		return { current = streak.current, lastClaimDay = streak.lastClaimDay }, 0, false
	end

	local newCurrent: number
	if today == streak.lastClaimDay + 1 then
		newCurrent = streak.current + 1
	else
		newCurrent = 1
	end

	local reward = 50 * math.min(newCurrent, 7)
	local newStreak: StreakState = { current = newCurrent, lastClaimDay = today }
	return newStreak, reward, true
end

return Streak
