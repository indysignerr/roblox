--!nonstrict
-- Progression system: daily streak claims, zone unlocks, nation score, win tracking.
--
-- Public API:
--   Server:
--     :AddWin(player)                        -> ()   increment wins + FireUpdated
--   Client (RemoteFunctions via Knit):
--     :ClaimDaily(player)  -> { claimed: boolean, reward: number, streak: number }
--     :UnlockZone(player, zoneId: string) -> boolean
--     :GetNationScore(player)             -> number

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Pure logic
local Streak = require(ReplicatedStorage.Shared.Logic.Streak)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Nation = require(ReplicatedStorage.Shared.Logic.Nation)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)

-- Config
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local ProgressionService = Knit.CreateService({
	Name = "ProgressionService",
	Client = {},
})

-- Cached service references (set in KnitInit)
local Data: any = nil

-- Pre-build the catalog index once at startup (Cards list is static).
local _catalogIndex: { [string]: any } = nil

local function getCatalog(): { [string]: any }
	if not _catalogIndex then
		_catalogIndex = Catalog.index(Cards)
	end
	return _catalogIndex
end

-- ---------------------------------------------------------------------------
-- Server-side public method (called by other services after a match win)
-- ---------------------------------------------------------------------------

function ProgressionService:AddWin(player: Player)
	local profile = Data:GetProfile(player)
	if not profile then
		return
	end
	profile.stats.wins += 1
	Data:FireUpdated(player)
end

-- ---------------------------------------------------------------------------
-- Client-facing methods
-- ---------------------------------------------------------------------------

-- Claim the daily streak reward.
-- Returns { claimed, reward, streak } where streak is the current streak value.
function ProgressionService.Client:ClaimDaily(
	player: Player
): { claimed: boolean, reward: number, streak: number }
	local profile = self.Server:_getProfile(player)
	if not profile then
		return { claimed = false, reward = 0, streak = 0 }
	end

	local today = Streak.dayNumber(os.time(), 0)
	local newStreak, reward, claimed = Streak.update(profile.streak, today)

	if claimed then
		profile.streak = newStreak
		Data:AddCoins(player, reward)
		Data:FireUpdated(player)
	end

	return { claimed = claimed, reward = reward, streak = profile.streak.current }
end

-- Attempt to unlock a zone. Returns true on success.
function ProgressionService.Client:UnlockZone(player: Player, zoneId: string): boolean
	local profile = self.Server:_getProfile(player)
	if not profile then
		return false
	end

	local ok, _reason = Zones.canUnlock(profile.unlockedZones, zoneId, profile.coins, ZoneConfig)
	if not ok then
		return false
	end

	local cost = ZoneConfig[zoneId].cost
	local spent = Data:AddCoins(player, -cost)
	if not spent then
		return false
	end

	profile.unlockedZones[zoneId] = true
	Data:FireUpdated(player)
	return true
end

-- Return the player's current nation leaderboard score.
function ProgressionService.Client:GetNationScore(player: Player): number
	local profile = self.Server:_getProfile(player)
	if not profile then
		return 0
	end

	local cv = Nation.collectionValue(profile.cards, getCatalog())
	return Nation.score(cv, profile.stats.wins, GameConfig.nationScore)
end

-- ---------------------------------------------------------------------------
-- Internal helper
-- ---------------------------------------------------------------------------

function ProgressionService:_getProfile(player: Player)
	return Data:GetProfile(player)
end

-- ---------------------------------------------------------------------------
-- Knit lifecycle
-- ---------------------------------------------------------------------------

function ProgressionService:KnitInit()
	Data = Knit.GetService("DataService")
end

function ProgressionService:KnitStart() end

return ProgressionService
