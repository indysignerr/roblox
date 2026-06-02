--!nonstrict
-- SocialController: emote/taunt other players, view their showcase, and spy their inventory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
local EmoteConfig = require(ReplicatedStorage.Shared.Config.EmoteConfig)

local SocialController = Knit.CreateController({
	Name = "SocialController",
})

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Clear all children (except layout/padding instances) from a frame.
local function clearChildren(frame: Frame)
	for _, child in frame:GetChildren() do
		if
			not child:IsA("UIListLayout")
			and not child:IsA("UIGridLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UISizeConstraint")
		then
			child:Destroy()
		end
	end
end

-- Resolve emote label from EmoteConfig by id.
local function resolveEmoteLabel(emoteId: string): string
	for _, emote in EmoteConfig do
		if emote.id == emoteId then
			return emote.label
		end
	end
	return emoteId
end

-- ── Build ─────────────────────────────────────────────────────────────────────

function SocialController:KnitInit()
	local Dock = Knit.GetController("DockController")

	Dock:Register({
		id = "social",
		label = "Social",
		order = 70,
		build = function(content)
			local Social = Knit.GetService("SocialService")
			local Purchase = Knit.GetService("PurchaseService")
			local idx = Catalog.index(Cards)

			-- Root vertical scroll list.
			local root = Components.ScrollList({
				Size = UDim2.fromScale(1, 1),
				gap = Theme.pad.md,
				padding = Theme.pad.sm,
				Parent = content,
			})

			-- ── Section 1 : Émotes / Provocations ────────────────────────────

			Components.Heading("Émotes / Provocations", {
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 1,
				Parent = root,
			})

			local emoteGrid = Components.Grid({
				Size = UDim2.new(1, 0, 0, 110),
				cell = Vector2.new(148, 44),
				gap = Theme.pad.sm,
				padding = 0,
				LayoutOrder = 2,
				Parent = root,
			})

			for i, emote in EmoteConfig do
				local capturedId = emote.id
				local capturedLabel = emote.label
				Components.Button({
					text = capturedLabel,
					variant = "secondary",
					Size = UDim2.fromOffset(148, 44),
					LayoutOrder = i,
					Parent = emoteGrid,
					onClick = function()
						Social:Taunt(capturedId)
							:andThen(function(ok)
								if not ok then
									Dock:Toast("Émote indisponible.", Theme.color.danger)
								end
							end)
							:catch(function()
								Dock:Toast("Émote indisponible.", Theme.color.danger)
							end)
					end,
				})
			end

			-- Listen for incoming taunts (connected once in build).
			Social.Taunted:Connect(function(senderUserId, emoteId)
				local player = Players:GetPlayerByUserId(senderUserId)
				local senderName = if player
					then player.DisplayName
					else "ID " .. tostring(senderUserId)
				local label = resolveEmoteLabel(emoteId)
				Dock:Toast(senderName .. " : " .. label)
			end)

			-- ── Separator ─────────────────────────────────────────────────────

			Components.Heading("Joueurs en ligne", {
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 3,
				Parent = root,
			})

			-- ── Section 2 : Player list ───────────────────────────────────────

			local playerList = Components.ScrollList({
				Size = UDim2.new(1, 0, 0, 180),
				gap = Theme.pad.xs,
				padding = 0,
				LayoutOrder = 4,
				Parent = root,
			})

			-- ── Section 3 : Result areas ──────────────────────────────────────

			-- Vitrine area (showcase results).
			Components.Heading("Vitrine", {
				Size = UDim2.new(1, 0, 0, 28),
				TextSize = Theme.text.md,
				LayoutOrder = 5,
				Parent = root,
			})

			local vitrineArea = Components.Grid({
				Size = UDim2.new(1, 0, 0, 180),
				cell = Vector2.new(120, 160),
				gap = Theme.pad.sm,
				padding = 0,
				LayoutOrder = 6,
				Parent = root,
			})

			-- Espionnage area (spy results).
			Components.Heading("Espionnage", {
				Size = UDim2.new(1, 0, 0, 28),
				TextSize = Theme.text.md,
				LayoutOrder = 7,
				Parent = root,
			})

			local spyArea = Components.ScrollList({
				Size = UDim2.new(1, 0, 0, 180),
				gap = Theme.pad.xs,
				padding = 0,
				LayoutOrder = 8,
				Parent = root,
			})

			-- "Acheter crédit espion" button — always visible.
			Components.Button({
				text = "Acheter crédit espion",
				variant = "ghost",
				Size = UDim2.new(1, 0, 0, 44),
				LayoutOrder = 9,
				Parent = root,
				onClick = function()
					Purchase:Prompt("spyReveal")
						:andThen(function(ok)
							if not ok then
								Dock:Toast(
									"Espionnage indisponible (à configurer).",
									Theme.color.warning
								)
							end
						end)
						:catch(function()
							Dock:Toast(
								"Espionnage indisponible (à configurer).",
								Theme.color.warning
							)
						end)
				end,
			})

			-- ── Player list builder ───────────────────────────────────────────

			local function buildPlayerRow(target: Player)
				local row = Components.create("Frame", {
					Size = UDim2.new(1, 0, 0, 48),
					BackgroundColor3 = Theme.color.surfaceAlt,
					BorderSizePixel = 0,
					LayoutOrder = target.UserId,
					Parent = playerList,
				})
				Components.corner(Theme.radius.md).Parent = row

				Components.Label(target.DisplayName, {
					Position = UDim2.fromOffset(Theme.pad.sm, 0),
					Size = UDim2.fromScale(0.45, 1),
					Parent = row,
				})

				-- "Voir vitrine" button.
				local targetUserId = target.UserId
				Components.Button({
					text = "Voir vitrine",
					variant = "secondary",
					Size = UDim2.fromOffset(110, 34),
					Position = UDim2.new(0.48, 0, 0.5, -17),
					Parent = row,
					onClick = function()
						Social:GetShowcase(targetUserId)
							:andThen(function(cardIds)
								clearChildren(vitrineArea)
								if not cardIds or #cardIds == 0 then
									Dock:Toast("Vitrine vide.")
									return
								end
								for order, cardId in cardIds do
									local def = idx[cardId]
									if def then
										Components.CardTile(def, nil, {
											LayoutOrder = order,
											Parent = vitrineArea,
										})
									end
								end
							end)
							:catch(function()
								Dock:Toast("Impossible de charger la vitrine.", Theme.color.danger)
							end)
					end,
				})

				-- "Espionner" button.
				Components.Button({
					text = "Espionner",
					variant = "danger",
					Size = UDim2.fromOffset(96, 34),
					Position = UDim2.new(1, -104, 0.5, -17),
					Parent = row,
					onClick = function()
						Social:Spy(targetUserId)
							:andThen(function(items)
								clearChildren(spyArea)
								if not items then
									Dock:Toast("Pas de crédit d'espion.", Theme.color.warning)
									return
								end
								for order, entry in items do
									local def = idx[entry.cardId]
									if def then
										Components.CardTile(def, entry.count, {
											LayoutOrder = order,
											Parent = spyArea,
										})
									end
								end
							end)
							:catch(function()
								Dock:Toast("Espionnage échoué.", Theme.color.danger)
							end)
					end,
				})
			end

			local function rebuildPlayerList()
				clearChildren(playerList)
				local localPlayer = Players.LocalPlayer
				for _, player in Players:GetPlayers() do
					if player ~= localPlayer then
						buildPlayerRow(player)
					end
				end
			end

			-- Initial population.
			rebuildPlayerList()

			-- Reactive updates.
			Players.PlayerAdded:Connect(function(_player)
				rebuildPlayerList()
			end)

			Players.PlayerRemoving:Connect(function(_player)
				rebuildPlayerList()
			end)

			-- Store rebuildPlayerList for onOpen use.
			SocialController._rebuildPlayerList = rebuildPlayerList
		end,

		onOpen = function()
			if SocialController._rebuildPlayerList then
				SocialController._rebuildPlayerList()
			end
		end,
	})
end

function SocialController:KnitStart() end

return SocialController
