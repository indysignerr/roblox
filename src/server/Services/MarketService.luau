--!nonstrict
-- Global market board. Players list cards for sale; others buy at posted price.
-- A progressive tax (by rarity) is deducted from the seller's payout.
--
-- Offline seller payouts are delivered via DataService:SendCoins (a persistent,
-- cross-server ProfileStore message), so no coins are ever dropped.
-- V1 limitation: listings themselves are in-memory (lost on server restart) -- a
-- global listing store (DataStore/MemoryStore) is a v2 follow-up.
--
-- Public API exposed to the client:
--   :List(player, cardId, price)      -> listingId? (string)
--   :Buy(player, listingId)           -> boolean
--   :Cancel(player, listingId)        -> boolean
--   :GetListings(player)              -> { Listing }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Market = require(ReplicatedStorage.Shared.Logic.Market)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

type Listing = {
	id: string,
	sellerUserId: number,
	cardId: string,
	price: number,
}

local MarketService = Knit.CreateService({
	Name = "MarketService",
	Client = {},

	_listings = {} :: { [string]: Listing },
	_nextId = 0,
})

local Data: any
local Inv: any

-- ── helpers ────────────────────────────────────────────────────────────────

local function nextListingId(self): string
	self._nextId += 1
	return "mkt_" .. tostring(self._nextId)
end

local function playerByUserId(userId: number): Player?
	for _, p in Players:GetPlayers() do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

-- ── client methods ─────────────────────────────────────────────────────────

-- List a card for sale. Returns the listing id, or nil on failure.
function MarketService.Client:List(player: Player, cardId: string, price: number): string?
	if type(price) ~= "number" or price <= 0 then
		return nil
	end
	if type(cardId) ~= "string" or cardId == "" then
		return nil
	end
	if not Inv:HasCard(player, cardId, 1) then
		return nil
	end
	-- Escrow: remove the card from inventory while it is listed.
	if not Inv:ConsumeCards(player, cardId, 1) then
		return nil
	end
	local id = nextListingId(self.Server)
	self.Server._listings[id] = {
		id = id,
		sellerUserId = player.UserId,
		cardId = cardId,
		price = price,
	}
	return id
end

-- Buy a listed card. Returns true on success.
function MarketService.Client:Buy(player: Player, listingId: string): boolean
	local listing = self.Server._listings[listingId]
	if not listing then
		return false
	end
	if listing.sellerUserId == player.UserId then
		return false
	end
	-- Deduct price from buyer first (fails if insufficient coins).
	if not Data:AddCoins(player, -listing.price) then
		return false
	end
	-- Compute seller payout after tax.
	local def = Catalog.get(Cards, listing.cardId)
	local rarity = if def then def.rarity else "Common"
	local taxRate = Market.taxRateFor(rarity, Rarities.marketTax)
	local net = Market.netProceeds(listing.price, taxRate)
	-- Pay the seller. Online -> credit instantly; offline -> persistent ProfileStore
	-- message that lands the next time they play (cross-server safe).
	local seller = playerByUserId(listing.sellerUserId)
	if seller then
		Data:AddCoins(seller, net)
	else
		Data:SendCoins(listing.sellerUserId, net)
	end
	-- Grant card to buyer and remove listing.
	Inv:GrantCard(player, listing.cardId)
	self.Server._listings[listingId] = nil
	return true
end

-- Cancel a listing (seller only). Returns the card to the seller's inventory.
function MarketService.Client:Cancel(player: Player, listingId: string): boolean
	local listing = self.Server._listings[listingId]
	if not listing then
		return false
	end
	if listing.sellerUserId ~= player.UserId then
		return false
	end
	Inv:GrantCard(player, listing.cardId)
	self.Server._listings[listingId] = nil
	return true
end

-- Snapshot of all current listings (sorted by id for determinism).
function MarketService.Client:GetListings(_player: Player): { Listing }
	local out: { Listing } = {}
	for _, listing in self.Server._listings do
		table.insert(out, listing)
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- ── lifecycle ──────────────────────────────────────────────────────────────

function MarketService:KnitInit()
	Data = Knit.GetService("DataService")
	Inv = Knit.GetService("InventoryService")
end

function MarketService:KnitStart() end

return MarketService

--[[
V2 FOLLOW-UP (not blocking):
  Listing PERSISTENCE -- `_listings` is in-memory and resets on server restart.
  A global, cross-server market needs a shared store (DataStore or MemoryStore)
  rather than per-profile data, since a listing isn't owned by a single session.
  Offline seller PAYOUTS are already solved via DataService:SendCoins (MessageAsync).
]]
