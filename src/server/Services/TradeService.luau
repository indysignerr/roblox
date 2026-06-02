--!nonstrict
-- Two-party P2P trade with a simple state machine.
-- Sessions are in-memory only (v1).
--
-- State machine per session:
--   OPEN -> either side calls SetOffer (clears confirmations) or Confirm.
--   When both sides have confirmed, Trade.validateOffer is run for each.
--   If both valid, the trade executes atomically; session closes.
--   Either side can Cancel at any time to abort.
--
-- Public API exposed to the client:
--   :Propose(player, targetUserId)          -> sessionId? (string)
--   :SetOffer(player, sessionId, offer)     -> boolean
--   :Confirm(player, sessionId)             -> boolean
--   :Cancel(player, sessionId)              -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trade = require(ReplicatedStorage.Shared.Logic.Trade)

type Offer = Trade.Offer

type Session = {
	id: string,
	userIds: { number }, -- [1] = proposer, [2] = target
	offers: { [number]: Offer }, -- keyed by userId
	confirmed: { [number]: boolean }, -- keyed by userId
}

local TradeService = Knit.CreateService({
	Name = "TradeService",
	Client = {},

	-- [sessionId] = Session
	_sessions = {} :: { [string]: Session },
	-- [userId] = sessionId  (so we can block double-sessions quickly)
	_playerSession = {} :: { [number]: string },
	_nextId = 0,
})

local Data: any
local Inv: any

-- ── helpers ────────────────────────────────────────────────────────────────

local function nextSessionId(self): string
	self._nextId += 1
	return "trade_" .. tostring(self._nextId)
end

local function playerByUserId(userId: number): Player?
	for _, p in Players:GetPlayers() do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function isOnline(userId: number): boolean
	return playerByUserId(userId) ~= nil
end

local function closeSession(self, sessionId: string)
	local session = self._sessions[sessionId]
	if not session then
		return
	end
	for _, uid in session.userIds do
		self._playerSession[uid] = nil
	end
	self._sessions[sessionId] = nil
end

-- Execute an agreed trade: consume each side's cards+coins, grant to the other side.
-- Returns true only if all operations succeed. On any failure the trade is aborted and
-- a best-effort rollback is attempted (grant back already-consumed items).
local function executeTrade(session: Session): boolean
	local uid1 = session.userIds[1]
	local uid2 = session.userIds[2]
	local p1 = playerByUserId(uid1)
	local p2 = playerByUserId(uid2)
	if not p1 or not p2 then
		return false
	end

	local offer1 = session.offers[uid1] or { cardIds = {}, coins = 0 }
	local offer2 = session.offers[uid2] or { cardIds = {}, coins = 0 }

	-- Consume p1's offer.
	local consumed1Cards: { string } = {}
	for _, cardId in offer1.cardIds do
		if not Inv:ConsumeCards(p1, cardId, 1) then
			-- Rollback consumed so far.
			for _, cid in consumed1Cards do
				Inv:GrantCard(p1, cid)
			end
			return false
		end
		table.insert(consumed1Cards, cardId)
	end
	local tookCoins1 = false
	if offer1.coins > 0 then
		if not Data:AddCoins(p1, -offer1.coins) then
			for _, cid in consumed1Cards do
				Inv:GrantCard(p1, cid)
			end
			return false
		end
		tookCoins1 = true
	end

	-- Consume p2's offer.
	local consumed2Cards: { string } = {}
	for _, cardId in offer2.cardIds do
		if not Inv:ConsumeCards(p2, cardId, 1) then
			-- Rollback p1.
			for _, cid in consumed1Cards do
				Inv:GrantCard(p1, cid)
			end
			if tookCoins1 then
				Data:AddCoins(p1, offer1.coins)
			end
			-- Rollback p2 partial.
			for _, cid in consumed2Cards do
				Inv:GrantCard(p2, cid)
			end
			return false
		end
		table.insert(consumed2Cards, cardId)
	end
	if offer2.coins > 0 then
		if not Data:AddCoins(p2, -offer2.coins) then
			for _, cid in consumed1Cards do
				Inv:GrantCard(p1, cid)
			end
			if tookCoins1 then
				Data:AddCoins(p1, offer1.coins)
			end
			for _, cid in consumed2Cards do
				Inv:GrantCard(p2, cid)
			end
			return false
		end
	end

	-- Grant p1's cards to p2 and p2's cards to p1.
	for _, cardId in offer1.cardIds do
		Inv:GrantCard(p2, cardId)
	end
	for _, cardId in offer2.cardIds do
		Inv:GrantCard(p1, cardId)
	end

	-- Grant coins cross-side.
	if offer1.coins > 0 then
		Data:AddCoins(p2, offer1.coins)
	end
	if offer2.coins > 0 then
		Data:AddCoins(p1, offer2.coins)
	end

	return true
end

-- ── client methods ─────────────────────────────────────────────────────────

-- Propose a trade to another online player. Returns session id or nil.
function TradeService.Client:Propose(player: Player, targetUserId: number): string?
	if player.UserId == targetUserId then
		return nil
	end
	if not isOnline(targetUserId) then
		return nil
	end
	-- Block if either party is already in a session.
	if self.Server._playerSession[player.UserId] then
		return nil
	end
	if self.Server._playerSession[targetUserId] then
		return nil
	end
	local id = nextSessionId(self.Server)
	local session: Session = {
		id = id,
		userIds = { player.UserId, targetUserId },
		offers = {},
		confirmed = {},
	}
	self.Server._sessions[id] = session
	self.Server._playerSession[player.UserId] = id
	self.Server._playerSession[targetUserId] = id
	return id
end

-- Record or replace a player's offer within a session. Clears both confirmations.
function TradeService.Client:SetOffer(player: Player, sessionId: string, offer: Offer): boolean
	local session = self.Server._sessions[sessionId]
	if not session then
		return false
	end
	-- Check this player belongs to the session.
	local belongs = false
	for _, uid in session.userIds do
		if uid == player.UserId then
			belongs = true
			break
		end
	end
	if not belongs then
		return false
	end
	session.offers[player.UserId] = { cardIds = offer.cardIds, coins = offer.coins }
	-- Any offer change resets both confirmations.
	session.confirmed = {}
	return true
end

-- Mark the player as confirmed. If both sides are confirmed, validate and execute.
-- Returns true whether the confirm was recorded OR the trade executed successfully.
-- Returns false on validation failure or execution error.
function TradeService.Client:Confirm(player: Player, sessionId: string): boolean
	local session = self.Server._sessions[sessionId]
	if not session then
		return false
	end
	local belongs = false
	for _, uid in session.userIds do
		if uid == player.UserId then
			belongs = true
			break
		end
	end
	if not belongs then
		return false
	end
	session.confirmed[player.UserId] = true

	-- Check if all parties have confirmed.
	local allConfirmed = true
	for _, uid in session.userIds do
		if not session.confirmed[uid] then
			allConfirmed = false
			break
		end
	end
	if not allConfirmed then
		return true -- own confirm recorded, waiting for the other side
	end

	-- Both confirmed: validate each offer.
	for _, uid in session.userIds do
		local p = playerByUserId(uid)
		if not p then
			closeSession(self.Server, sessionId)
			return false
		end
		local profile = Data:GetProfile(p)
		if not profile then
			closeSession(self.Server, sessionId)
			return false
		end
		local offer = session.offers[uid] or { cardIds = {}, coins = 0 }
		local ok, reason = Trade.validateOffer(profile.cards, profile.coins, offer)
		if not ok then
			warn(
				string.format(
					"[TradeService] Offer validation failed for userId %d in session %s: %s",
					uid,
					sessionId,
					reason
				)
			)
			closeSession(self.Server, sessionId)
			return false
		end
	end

	-- Execute atomically.
	local executed = executeTrade(session)
	closeSession(self.Server, sessionId)
	return executed
end

-- Abort the session. Either party may cancel.
function TradeService.Client:Cancel(player: Player, sessionId: string): boolean
	local session = self.Server._sessions[sessionId]
	if not session then
		return false
	end
	local belongs = false
	for _, uid in session.userIds do
		if uid == player.UserId then
			belongs = true
			break
		end
	end
	if not belongs then
		return false
	end
	closeSession(self.Server, sessionId)
	return true
end

-- ── lifecycle ──────────────────────────────────────────────────────────────

function TradeService:KnitInit()
	Data = Knit.GetService("DataService")
	Inv = Knit.GetService("InventoryService")
end

function TradeService:KnitStart()
	-- Clean up sessions when a player leaves.
	Players.PlayerRemoving:Connect(function(player)
		local sessionId = self._playerSession[player.UserId]
		if sessionId then
			closeSession(self, sessionId)
		end
	end)
end

return TradeService
