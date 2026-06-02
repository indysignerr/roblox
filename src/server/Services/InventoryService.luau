--!nonstrict
-- Card-mutation primitive. Every system that grants/consumes cards goes through here
-- so anti-dupe and replication stay in one place. Wraps the pure Inventory logic and
-- writes to the live profile via DataService.
--
-- Public API (STABLE):
--   :GrantCard(player, cardId) -> boolean          -- add one copy (stacks)
--   :ConsumeCards(player, cardId, n) -> boolean     -- false if not enough copies
--   :HasCard(player, cardId, n?) -> boolean
--   :GetCard(player, cardId) -> OwnedCard?
--   :ConvertDuplicates(player, cardId, keep?) -> number  -- anti-dupe: surplus -> coins

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Inventory = require(ReplicatedStorage.Shared.Logic.Inventory)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {},
})

local Data

function InventoryService:GrantCard(player: Player, cardId: string): boolean
	local profile = Data:GetProfile(player)
	if not profile then
		return false
	end
	Inventory.grant(profile.cards, cardId)
	Data:FireUpdated(player)
	return true
end

function InventoryService:ConsumeCards(player: Player, cardId: string, n: number): boolean
	local profile = Data:GetProfile(player)
	if not profile then
		return false
	end
	local ok = Inventory.consume(profile.cards, cardId, n)
	if ok then
		Data:FireUpdated(player)
	end
	return ok
end

function InventoryService:HasCard(player: Player, cardId: string, n: number?): boolean
	local profile = Data:GetProfile(player)
	return profile ~= nil and Inventory.has(profile.cards, cardId, n)
end

function InventoryService:GetCard(player: Player, cardId: string)
	local profile = Data:GetProfile(player)
	return if profile then profile.cards[cardId] else nil
end

function InventoryService:ConvertDuplicates(player: Player, cardId: string, keep: number?): number
	local profile = Data:GetProfile(player)
	if not profile then
		return 0
	end
	local def = Catalog.get(Cards, cardId)
	if not def then
		return 0
	end
	local perCopy = Rarities.dupeValue[def.rarity] or 0
	local coins = Inventory.convertDuplicates(profile.cards, cardId, perCopy, keep)
	if coins > 0 then
		Data:AddCoins(player, coins) -- fires Updated
	end
	return coins
end

function InventoryService:KnitInit()
	Data = Knit.GetService("DataService")
end

function InventoryService:KnitStart() end

return InventoryService
