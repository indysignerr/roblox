--!nonstrict
-- Manages per-player shields (activation, reactivation, expiry queries).
-- Pure logic lives in src/shared/Logic/Shield.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Shield = require(ReplicatedStorage.Shared.Logic.Shield)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ShieldService = Knit.CreateService({
	Name = "ShieldService",
	Client = {},
})

local Data

-- ─── Server API ─────────────────────────────────────────────────────────────

-- Returns true when the player's shield is currently active and unexpired.
function ShieldService:IsActive(player: Player): boolean
	local profile = Data:GetProfile(player)
	if not profile then
		return false
	end
	return Shield.isActive(profile.shield, os.time())
end

-- Activate (or refresh) the player's shield using the standard duration.
function ShieldService:Activate(player: Player)
	local profile = Data:GetProfile(player)
	if not profile then
		return
	end
	profile.shield = Shield.activate(os.time(), GameConfig.shield.durationSeconds)
	Data:FireUpdated(player)
end

-- ─── Client API ─────────────────────────────────────────────────────────────

-- Paid reactivation: charges reactivateCost coins; returns false if the player
-- cannot afford it or is not loaded.
function ShieldService.Client:Reactivate(player: Player): boolean
	local cost = GameConfig.shield.reactivateCost
	local ok = Data:AddCoins(player, -cost)
	if not ok then
		return false
	end
	self.Server:Activate(player)
	return true
end

-- Returns the number of seconds of protection remaining for the caller.
function ShieldService.Client:GetRemaining(player: Player): number
	local profile = Data:GetProfile(player)
	if not profile then
		return 0
	end
	return Shield.remaining(profile.shield, os.time())
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

function ShieldService:KnitInit()
	Data = Knit.GetService("DataService")
end

function ShieldService:KnitStart() end

return ShieldService
