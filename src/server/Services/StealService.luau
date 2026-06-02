--!nonstrict
-- Handles the Steal a Brainrot loop: a thief targets another online player,
-- bypasses (or is blocked by) their shield, and swaps one card.
-- Pure steal logic lives in src/shared/Logic/Steal.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Steal = require(ReplicatedStorage.Shared.Logic.Steal)

local StealService = Knit.CreateService({
	Name = "StealService",
	Client = {},
})

local Data
local Inv
local ShieldSvc

-- ─── Client API ─────────────────────────────────────────────────────────────

-- Attempt to steal one card from `victimUserId`.
-- Returns { success: boolean, cardId: string?, reason: string? }.
function StealService.Client:Attempt(
	thief: Player,
	victimUserId: number
): { success: boolean, cardId: string?, reason: string? }
	-- Self-steal guard.
	if thief.UserId == victimUserId then
		return { success = false, reason = "self" }
	end

	-- Victim must be online.
	local victim = Players:GetPlayerByUserId(victimUserId)
	if victim == nil then
		return { success = false, reason = "offline" }
	end

	-- Both profiles must be loaded.
	local thiefProfile = Data:GetProfile(thief)
	local victimProfile = Data:GetProfile(victim)
	if not thiefProfile or not victimProfile then
		return { success = false, reason = "offline" }
	end

	-- Evaluate shield and card availability via pure logic.
	local victimShieldActive = ShieldSvc:IsActive(victim)
	local cardIds: { string } = {}
	for id in victimProfile.cards do
		table.insert(cardIds, id)
	end

	local canProceed, reason = Steal.canSteal(victimShieldActive, cardIds)
	if not canProceed then
		return { success = false, reason = reason }
	end

	-- Pick the card to steal.
	local cardId = Steal.pickTarget(cardIds, math.random())
	if not cardId then
		-- Defensive: list became empty between the check above and now.
		return { success = false, reason = "empty" }
	end

	-- Execute the transfer.
	local consumed = Inv:ConsumeCards(victim, cardId, 1)
	if not consumed then
		return { success = false, reason = "empty" }
	end
	Inv:GrantCard(thief, cardId)

	-- Update stats.
	victimProfile.stats.stolenFrom += 1
	thiefProfile.stats.steals += 1

	-- Grant victim a grace-period shield.
	ShieldSvc:Activate(victim)

	-- Fire client updates for both players (InventoryService already fires for
	-- card mutations; fire again so shield + stats are reflected too).
	Data:FireUpdated(victim)
	Data:FireUpdated(thief)

	return { success = true, cardId = cardId }
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

function StealService:KnitInit()
	Data = Knit.GetService("DataService")
	Inv = Knit.GetService("InventoryService")
	ShieldSvc = Knit.GetService("ShieldService")
end

function StealService:KnitStart() end

return StealService
