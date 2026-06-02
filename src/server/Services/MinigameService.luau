--!nonstrict
-- Minigame Service: penalty shootout (solo) + co-op boss fight.
-- Pure logic lives in src/shared/Logic/Penalty.luau and Boss.luau.
-- Depends on DataService (AddCoins) and InventoryService (GrantCard).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Penalty = require(ReplicatedStorage.Shared.Logic.Penalty)
local Boss = require(ReplicatedStorage.Shared.Logic.Boss)
local MinigameConfig = require(ReplicatedStorage.Shared.Config.MinigameConfig)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local RarityRoll = require(ReplicatedStorage.Shared.Logic.RarityRoll)

-- In-memory boss state (server-authoritative, non-persistent).
type BossState = {
	hp: number,
	participants: { [number]: boolean }, -- userId -> true
}

local MinigameService = Knit.CreateService({
	Name = "MinigameService",
	Client = {},

	_boss = nil :: BossState?,
})

local Data: any
local Inv: any

-- ─── Server helpers ───────────────────────────────────────────────────────────

-- Spawn a fresh boss if none exists.
function MinigameService:SpawnBoss()
	if self._boss ~= nil then
		return
	end
	self._boss = {
		hp = MinigameConfig.boss.maxHp,
		participants = {},
	}
end

-- Pick a random card from the full catalogue.
local function randomCardId(): string
	local rarity = RarityRoll.pick(Rarities.weights, Rarities.order, math.random())
	local pool = Catalog.byRarity(Cards, rarity)
	if #pool == 0 then
		-- Fallback: any card.
		return Cards[math.random(1, #Cards)].id
	end
	return pool[math.random(1, #pool)].id
end

-- ─── Client methods ───────────────────────────────────────────────────────────

-- PlayPenalty: player picks a shot direction (1..5); server picks keeper direction.
-- Returns { goal: boolean, reward: number, keeperDir: number }.
function MinigameService.Client:PlayPenalty(
	player: Player,
	shotDir: number
): { goal: boolean, reward: number, keeperDir: number }
	local keeperDir = math.random(1, 5)
	local isGoal = Penalty.resolve(shotDir, keeperDir)
	local reward = Penalty.reward(isGoal, MinigameConfig.penalty)
	Data:AddCoins(player, reward)
	Data:FireUpdated(player)
	return { goal = isGoal, reward = reward, keeperDir = keeperDir }
end

-- AttackBoss: player deals damage to the shared boss.
-- dmg is clamped to [0, 500]. Spawns the boss if it doesn't exist yet.
-- Returns { hp: number, dead: boolean }.
function MinigameService.Client:AttackBoss(
	player: Player,
	dmg: number
): { hp: number, dead: boolean }
	self.Server:SpawnBoss()
	local bossState = self.Server._boss :: BossState

	-- Clamp damage to valid range.
	local safeDmg = math.clamp(dmg, 0, 500)

	-- Record this player as a participant.
	bossState.participants[player.UserId] = true

	-- Apply damage.
	bossState.hp = Boss.applyDamage(bossState.hp, safeDmg)
	local dead = Boss.isDead(bossState.hp)

	if dead then
		-- Distribute rewards to all participants who are still online.
		local participantCount = 0
		for _ in bossState.participants do
			participantCount += 1
		end
		local coinReward = Boss.splitReward(MinigameConfig.boss.totalReward, participantCount)

		for userId in bossState.participants do
			local target = Players:GetPlayerByUserId(userId)
			if target then
				Data:AddCoins(target, coinReward)
				-- Chance-based card drop.
				if math.random() < MinigameConfig.boss.rewardCardChance then
					local cardId = randomCardId()
					Inv:GrantCard(target, cardId)
				end
				Data:FireUpdated(target)
			end
		end

		-- Clear the boss for the next round.
		self.Server._boss = nil
	end

	return { hp = bossState.hp, dead = dead }
end

-- GetBoss: snapshot of the current boss state (nil when no boss is active).
function MinigameService.Client:GetBoss(_player: Player): { hp: number }?
	local bossState = self.Server._boss
	if bossState == nil then
		return nil
	end
	return { hp = bossState.hp }
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function MinigameService:KnitInit()
	Data = Knit.GetService("DataService")
	Inv = Knit.GetService("InventoryService")
end

function MinigameService:KnitStart() end

return MinigameService
