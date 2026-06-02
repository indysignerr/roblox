--!nonstrict
-- Global market board. Players list cards for sale; others buy at posted price.
-- A progressive tax (by rarity) is deducted from the seller's payout.
--
-- V1: listings are in-memory only (lost on server restart).
-- Offline seller payouts are skipped and reported below.
--
-- LOCKED-FILE NEEDS / V1 LIMITATIONS (see end of file):
--   - Listing persistence requires a new `marketListings` field in ProfileData
--     (edit DataService / the profile template -- LOCKED).
--   - Offline seller payout requires a mailbox/inbox field in ProfileData
--     (edit DataService -- LOCKED).
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
	-- Pay seller (online only in v1; offline payout skipped -- see LOCKED-FILE NEEDS).
	local seller = playerByUserId(listing.sellerUserId)
	if seller then
		Data:AddCoins(seller, net)
	else
		-- V1: seller is offline; payout is forfeited this session.
		-- TODO: persist payout in a mailbox field on ProfileData (requires DataService edit).
		warn(
			string.format(
				"[MarketService] Seller %d is offline; net payout of %d coins for listing %s skipped (v1).",
				listing.sellerUserId,
				net,
				listingId
			)
		)
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
LOCKED-FILE NEEDS / V1 LIMITATIONS
====================================
1. LISTING PERSISTENCE
   Market listings are stored in `MarketService._listings` (in-memory) and are
   lost when the server restarts. To persist them across sessions, a new field
   `marketListings: { [string]: { sellerUserId:number, cardId:string, price:number } }?`
   needs to be added to ProfileData in `src/shared/Types.luau` (LOCKED) and the
   PROFILE_TEMPLATE in `src/server/Services/DataService.luau` (LOCKED).
   The service would then serialise/deserialise to the seller's profile on load/save.

2. OFFLINE SELLER PAYOUTS
   When a buyer purchases a listing while the seller is offline the payout is
   currently dropped (a `warn()` is emitted). Correct behaviour requires a
   mailbox/inbox mechanism: a `pendingCoins: number` (or richer inbox) field on
   ProfileData, credited at purchase time and drained when the seller next logs in
   (via `DataService.ProfileLoaded`). This also requires editing the LOCKED files
   above. Implementing a separate in-memory queue was avoided because it resets on
   server restart and would silently swallow coins.
]]
