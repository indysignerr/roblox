--!nonstrict
-- Fusion Service: lets a player sacrifice 5 Rare cards for a chance at an Epic.
-- Depends on DataService, InventoryService (card mutation), Catalog, Cards,
-- Rarities (read-only; kept for future use), GameConfig.
--
-- Public API:
--   .Client:Fuse(player)     -> { success, outputCardId?, consumed?, reason? }
--   .Client:CanFuse(player)  -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Logic.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local FusionService = Knit.CreateService({
	Name = "FusionService",
	Client = {},
})

local Data: any
local Inv: any

-- Helper: collect eligible inputs for the given player profile.
local function collectForPlayer(profile: any): { string }?
	local cfg = GameConfig.fusion
	local idx = Catalog.index(Cards)
	return Fusion.collectInputs(profile.cards, idx, cfg.inputRarity, cfg.inputCount)
end

-- .Client:Fuse(player) -> { success, outputCardId?, consumed?, reason? }
-- Consumes ALL inputs regardless of outcome (risky fusion), increments stats,
-- then on success grants one randomly chosen Epic card.
function FusionService.Client:Fuse(player: Player)
	local profile = Data:GetProfile(player)
	if not profile then
		return { success = false, reason = "not_loaded" }
	end

	local cfg = GameConfig.fusion
	local inputs = collectForPlayer(profile)
	if not inputs then
		return { success = false, reason = "not_enough" }
	end

	-- Consume all inputs (risky: consumed regardless of outcome).
	for _, cardId in inputs do
		Inv:ConsumeCards(player, cardId, 1)
	end

	-- Increment fusion counter.
	profile.stats.fusions += 1

	local roll = math.random()
	if Fusion.resolve(roll, cfg.successRate) then
		-- Build the output pool and pick one.
		local outputCards = Catalog.byRarity(Cards, cfg.outputRarity)
		local outputIds: { string } = {}
		for _, def in outputCards do
			table.insert(outputIds, def.id)
		end

		local outputRoll = math.random()
		local outputCardId = Fusion.pickOutput(outputIds, outputRoll)
		if outputCardId then
			Inv:GrantCard(player, outputCardId)
		end

		Data:FireUpdated(player)
		return { success = true, outputCardId = outputCardId, consumed = inputs }
	else
		Data:FireUpdated(player)
		return { success = false, consumed = inputs, reason = "failed" }
	end
end

-- .Client:CanFuse(player) -> boolean
-- Returns true when the player has enough eligible cards to attempt a fusion.
function FusionService.Client:CanFuse(player: Player): boolean
	local profile = Data:GetProfile(player)
	if not profile then
		return false
	end
	return collectForPlayer(profile) ~= nil
end

function FusionService:KnitInit()
	Data = Knit.GetService("DataService")
	Inv = Knit.GetService("InventoryService")
end

function FusionService:KnitStart() end

return FusionService
