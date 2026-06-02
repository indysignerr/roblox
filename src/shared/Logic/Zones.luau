--!strict
-- Pure zone-unlock logic. No requires, no Roblox globals -> Lune-testable.

type ZoneCfg = {
	name: string,
	cost: number,
}

local Zones = {}

-- Check whether a player can unlock the given zone.
-- Returns (canUnlock: boolean, reason: string):
--   "owned"   - already unlocked
--   "unknown" - zoneId not in zoneCfg
--   "poor"    - not enough coins
--   "ok"      - unlock is permitted
function Zones.canUnlock(
	unlockedZones: { [string]: boolean },
	zoneId: string,
	coins: number,
	zoneCfg: { [string]: ZoneCfg }
): (boolean, string)
	if unlockedZones[zoneId] then
		return false, "owned"
	end

	local cfg = zoneCfg[zoneId]
	if not cfg then
		return false, "unknown"
	end

	if coins < cfg.cost then
		return false, "poor"
	end

	return true, "ok"
end

return Zones
