--!nonstrict
-- PurchaseService: the single owner of MarketplaceService.ProcessReceipt.
-- Validates Robux developer-product purchases SERVER-SIDE and grants their rewards
-- (coins, spy credits). Clients can only *prompt* a purchase; they never assert payment.
--
-- Public API:
--   .Client:Prompt(player, productKey) -> boolean   -- opens the Robux purchase UI
--   :HasReward(productKey) -> boolean                -- is this product configured (productId ~= 0)
--
-- NOTE (production hardening): receipt idempotency here is an in-memory guard keyed by
-- PlayerId+PurchaseId. That is correct within a server's lifetime. For bullet-proof
-- cross-restart dedupe, persist granted PurchaseIds in the profile and check them here.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ProductConfig = require(ReplicatedStorage.Shared.Config.ProductConfig)

local PurchaseService = Knit.CreateService({
	Name = "PurchaseService",
	Client = {},

	_rewardByProductId = {}, -- [productId:number] = ProductEntry
	_processed = {}, -- ["<playerId>_<purchaseId>"] = true (per-session dedupe)
})

local Data

local function grantReward(player: Player, entry): boolean
	local profile = Data:GetProfile(player)
	if not profile then
		return false
	end
	if entry.coins then
		Data:AddCoins(player, entry.coins)
	end
	if entry.spyCredits then
		profile.spyCredits = (profile.spyCredits or 0) + entry.spyCredits
		Data:FireUpdated(player)
	end
	return true
end

-- Returns true if the named product has a real (non-zero) configured productId.
function PurchaseService:HasReward(productKey: string): boolean
	local entry = ProductConfig[productKey]
	return entry ~= nil and entry.productId ~= 0
end

-- Client asks the server to open the Robux purchase prompt for a named product.
-- Returns false if the product isn't configured yet (productId == 0).
function PurchaseService.Client:Prompt(player: Player, productKey: string): boolean
	if not self.Server:HasReward(productKey) then
		return false
	end
	local entry = ProductConfig[productKey]
	MarketplaceService:PromptProductPurchase(player, entry.productId)
	return true
end

function PurchaseService:_processReceipt(receiptInfo)
	local entry = self._rewardByProductId[receiptInfo.ProductId]
	if not entry then
		-- Unknown product (e.g. mapping not deployed yet) -- ask Roblox to retry later
		-- rather than silently consuming the player's Robux.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = `{receiptInfo.PlayerId}_{receiptInfo.PurchaseId}`
	if self._processed[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not grantReward(player, entry) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self._processed[key] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService:KnitInit()
	Data = Knit.GetService("DataService")

	for _, entry in ProductConfig do
		if entry.productId ~= 0 then
			self._rewardByProductId[entry.productId] = entry
		end
	end

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end
end

function PurchaseService:KnitStart() end

return PurchaseService
