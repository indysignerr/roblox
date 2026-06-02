--!nonstrict
-- Central player-data service. Every other system reads/writes the profile through here.
--
-- Backend: session-locked ProfileStore (vendor/ProfileStore.luau). In Studio without API
-- access ProfileStore transparently falls back to a mock store, so this runs locally too.
--
-- Public API (STABLE -- other services build against this):
--   :GetProfile(player) -> ProfileData?   -- the live, mutable Data table (mutate in place)
--   :GetCoins(player) -> number
--   :AddCoins(player, amount) -> boolean   -- false if the spend would go negative
--   .ProfileLoaded    Signal(player, data)
--   .ProfileReleasing Signal(player, data)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

type ProfileData = Types.ProfileData

-- Static defaults. Reconcile() fills these into existing profiles missing keys.
-- `createdAt` starts at 0 and is stamped on first load (templates must be static/hard-copyable).
local PROFILE_TEMPLATE: ProfileData = {
	coins = GameConfig.startingCoins,
	cards = {},
	shield = { active = false, expiresAt = 0 },
	streak = { current = 0, lastClaimDay = 0 },
	teamId = nil,
	unlockedZones = { spawn = true },
	lastDailyPackDay = 0,
	stats = { steals = 0, stolenFrom = 0, fusions = 0, wins = 0 },
	createdAt = 0,
}

local Store = ProfileStore.New("PlayerData_v1", PROFILE_TEMPLATE)

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		-- Fired to a single player when their own profile changes (UI re-renders on this).
		Updated = Knit.CreateSignal(), -- (data: ProfileData)
	},

	_profiles = {}, -- [Player] = Profile (ProfileStore profile; .Data is the ProfileData)
})

DataService.ProfileLoaded = Signal.new() -- (player: Player, data: ProfileData)
DataService.ProfileReleasing = Signal.new() -- (player: Player, data: ProfileData)

-- Returns the live, mutable profile data, or nil if the player is not (yet) loaded.
function DataService:GetProfile(player: Player): ProfileData?
	local profile = self._profiles[player]
	return if profile then profile.Data else nil
end

-- Call after mutating a profile so the owning client re-renders.
function DataService:FireUpdated(player: Player)
	local profile = self._profiles[player]
	if profile then
		self.Client.Updated:Fire(player, profile.Data)
	end
end

-- Client read: a player may fetch their own profile (no server secrets live in it).
function DataService.Client:GetProfile(player: Player): ProfileData?
	return self.Server:GetProfile(player)
end

function DataService:GetCoins(player: Player): number
	local profile = self._profiles[player]
	return if profile then profile.Data.coins else 0
end

-- Adds (or removes, if negative) coins. Returns false if the spend would go negative.
function DataService:AddCoins(player: Player, amount: number): boolean
	local profile = self._profiles[player]
	if not profile then
		return false
	end
	if profile.Data.coins + amount < 0 then
		return false
	end
	profile.Data.coins += amount
	self:FireUpdated(player)
	return true
end

function DataService:_load(player: Player)
	local profile = Store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Another server holds the lock and wouldn't release; let the player retry.
		player:Kick("Données indisponibles. Rejoins le jeu.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if profile.Data.createdAt == 0 then
		profile.Data.createdAt = os.time()
	end

	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		player:Kick("Session de données terminée. Rejoins le jeu.")
	end)

	if player.Parent == Players then
		self._profiles[player] = profile
		self.ProfileLoaded:Fire(player, profile.Data)
	else
		-- Player left before the session finished starting.
		profile:EndSession()
	end
end

function DataService:_release(player: Player)
	local profile = self._profiles[player]
	if profile then
		self.ProfileReleasing:Fire(player, profile.Data)
		profile:EndSession()
		self._profiles[player] = nil
	end
end

function DataService:KnitInit()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_load(player)
		end)
	end
end

function DataService:KnitStart() end

return DataService
