--!nonstrict
-- PackService: daily, nation, and flash pack opening.
-- Pure logic lives in src/shared/Logic/Packs.luau (testable under Lune).
-- All card mutations go through InventoryService; coin changes through DataService.
--
-- Public server API:
--   :OpenDaily(player)  -> string?   -- cardId on success, nil if already claimed today
--   :OpenNation(player, nation)      -> string?   -- costs nationPackCoinCost
--   :OpenFlash(player)  -> string?   -- available only during an active flash window
--   :StartFlash()                    -- admin / scheduler call to open a flash window
--   :IsFlashActive()    -> boolean
--
-- .Client methods (RemoteFunctions):
--   OpenDaily(player)           -> string?
--   OpenNation(player, nation)  -> string?
--   OpenFlash(player)           -> string?
--   CanClaimDaily(player)       -> boolean
--   IsFlashActive(player)       -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Packs = require(ReplicatedStorage.Shared.Logic.Packs)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local PackService = Knit.CreateService({
	Name = "PackService",
	Client = {},

	_flashUntil = 0, -- os.time() deadline for the current flash window
})

local Data -- DataService
local Inv -- InventoryService

-- ----------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------

local function todayNumber(): number
	return Packs.dayNumber(os.time(), GameConfig.packs.dailyResetHour)
end

-- ----------------------------------------------------------------
-- Server-side methods
-- ----------------------------------------------------------------

function PackService:OpenDaily(player: Player): string?
	local profile = Data:GetProfile(player)
	if not profile then
		return nil
	end

	local today = todayNumber()
	if not Packs.canClaimDaily(profile.lastDailyPackDay, today) then
		return nil
	end

	local rarityRoll = math.random()
	local rarity = Packs.rollRarity(Rarities.weights, Rarities.order, rarityRoll)

	local pool = Catalog.byRarity(Cards, rarity)
	local cardRoll = math.random()
	local def = Packs.pickFromList(pool, cardRoll)
	if not def then
		return nil
	end

	local granted = Inv:GrantCard(player, def.id)
	if not granted then
		return nil
	end

	profile.lastDailyPackDay = today
	Data:FireUpdated(player)

	return def.id
end

function PackService:OpenNation(player: Player, nation: string): string?
	local profile = Data:GetProfile(player)
	if not profile then
		return nil
	end

	local cost = GameConfig.packs.nationPackCoinCost
	local ok = Data:AddCoins(player, -cost)
	if not ok then
		return nil
	end

	local rarityRoll = math.random()
	local rarity = Packs.rollRarity(Rarities.weights, Rarities.order, rarityRoll)

	-- Cards matching both nation and rolled rarity; fall back to any card of that nation.
	local byNation = Catalog.byNation(Cards, nation)

	local pool: { any } = {}
	for _, def in byNation do
		if def.rarity == rarity then
			table.insert(pool, def)
		end
	end

	local cardRoll = math.random()
	local def = Packs.pickFromList(if #pool > 0 then pool else byNation, cardRoll)
	if not def then
		-- Refund — invalid nation or empty catalogue; do not leave the player coinless.
		Data:AddCoins(player, cost)
		return nil
	end

	Inv:GrantCard(player, def.id)
	return def.id
end

function PackService:OpenFlash(player: Player): string?
	if not self:IsFlashActive() then
		return nil
	end

	local rarityRoll = math.random()
	local rarity = Packs.rollRarity(Rarities.weights, Rarities.order, rarityRoll)

	local pool = Catalog.byRarity(Cards, rarity)
	local cardRoll = math.random()
	local def = Packs.pickFromList(pool, cardRoll)
	if not def then
		return nil
	end

	Inv:GrantCard(player, def.id)
	return def.id
end

-- Activate a flash window of GameConfig.packs.flashDurationSeconds seconds.
function PackService:StartFlash()
	self._flashUntil = os.time() + GameConfig.packs.flashDurationSeconds
end

function PackService:IsFlashActive(): boolean
	return os.time() < self._flashUntil
end

-- ----------------------------------------------------------------
-- Client surface
-- ----------------------------------------------------------------

function PackService.Client:OpenDaily(player: Player): string?
	return self.Server:OpenDaily(player)
end

function PackService.Client:OpenNation(player: Player, nation: string): string?
	return self.Server:OpenNation(player, nation)
end

function PackService.Client:OpenFlash(player: Player): string?
	return self.Server:OpenFlash(player)
end

function PackService.Client:CanClaimDaily(player: Player): boolean
	local profile = Data:GetProfile(player)
	if not profile then
		return false
	end
	return Packs.canClaimDaily(profile.lastDailyPackDay, todayNumber())
end

function PackService.Client:IsFlashActive(_player: Player): boolean
	return self.Server:IsFlashActive()
end

-- ----------------------------------------------------------------
-- Knit lifecycle
-- ----------------------------------------------------------------

function PackService:KnitInit()
	Data = Knit.GetService("DataService")
	Inv = Knit.GetService("InventoryService")
end

function PackService:KnitStart() end

return PackService
