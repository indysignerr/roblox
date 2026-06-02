--!nonstrict
-- SocialService: trash-talk taunts, card showcase, and Robux-gated spy.
-- Thin shell over Social (pure logic). Depends on DataService + Catalog + Cards + EmoteConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Social = require(ReplicatedStorage.Shared.Logic.Social)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local EmoteConfig = require(ReplicatedStorage.Shared.Config.EmoteConfig)

local SocialService = Knit.CreateService({
	Name = "SocialService",
	Client = {
		-- Fired to all players when someone taunts: (senderUserId: number, emoteId: string)
		Taunted = Knit.CreateSignal(),
	},
})

local Data

-- :Taunt(player, emoteId) -> boolean
-- Validates the emote and, if valid, broadcasts to all connected players.
function SocialService.Client:Taunt(player: Player, emoteId: string): boolean
	local valid = Social.isValidEmote(EmoteConfig, emoteId)
	if valid then
		for _, p in Players:GetPlayers() do
			self.Server.Client.Taunted:Fire(p, player.UserId, emoteId)
		end
	end
	return valid
end

-- :GetShowcase(player, targetUserId) -> { string }
-- Returns the top 5 card ids (by basePower DESC) for the target player.
-- Returns {} if the target is offline or has no profile loaded.
function SocialService.Client:GetShowcase(_player: Player, targetUserId: number): { string }
	local target: Player? = nil
	for _, p in Players:GetPlayers() do
		if p.UserId == targetUserId then
			target = p
			break
		end
	end

	if not target then
		return {}
	end

	local profile = Data:GetProfile(target)
	if not profile then
		return {}
	end

	local catalogIndex = Catalog.index(Cards)
	return Social.topCards(profile.cards, catalogIndex, 5)
end

-- :Spy(player, targetUserId, hasPaid) -> { {cardId: string, count: number} }?
-- Returns nil if hasPaid is false (Robux gate).
-- Otherwise returns the target's full collection as a list of {cardId, count}.
-- Returns nil also if the target is offline.
function SocialService.Client:Spy(
	_player: Player,
	targetUserId: number,
	hasPaid: boolean
): { { cardId: string, count: number } }?
	if not Social.canSpy(hasPaid) then
		return nil
	end

	local target: Player? = nil
	for _, p in Players:GetPlayers() do
		if p.UserId == targetUserId then
			target = p
			break
		end
	end

	if not target then
		return nil
	end

	local profile = Data:GetProfile(target)
	if not profile then
		return nil
	end

	local summary: { { cardId: string, count: number } } = {}
	for cardId, owned in profile.cards do
		table.insert(summary, { cardId = cardId, count = owned.count })
	end
	return summary
end

function SocialService:KnitInit()
	Data = Knit.GetService("DataService")
end

function SocialService:KnitStart() end

return SocialService
