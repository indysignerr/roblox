--!nonstrict
-- MarketController: global market (list/buy/cancel cards) + basic peer-to-peer trade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)

local MarketController = Knit.CreateController({
	Name = "MarketController",

	_profile = nil,
	_idx = nil,

	-- Market sub-section state
	_marketContainer = nil,
	_listingsScroll = nil,
	_ownedScroll = nil,
	_priceBox = nil,
	_selectedCardId = nil,

	-- Trade sub-section state
	_tradeContainer = nil,
	_currentSessionId = nil,
	_tradeStatus = nil,
	_playersScroll = nil,
	_offerScroll = nil,
	_coinsBox = nil,
	_selectedOfferCards = nil,
	_offerSection = nil,
})

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function clearChildren(parent)
	for _, ch in parent:GetChildren() do
		if not ch:IsA("UILayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

-- ── Market refresh ────────────────────────────────────────────────────────────

function MarketController:_refreshListings()
	local Market = Knit.GetService("MarketService")
	local Dock = Knit.GetController("DockController")
	Market:GetListings()
		:andThen(function(list)
			clearChildren(self._listingsScroll)
			if not list or #list == 0 then
				Components.Label("Aucune annonce en ce moment.", {
					dim = true,
					Parent = self._listingsScroll,
				})
				return
			end
			for _, listing in list do
				local def = self._idx and self._idx[listing.cardId]
				if not def then
					continue
				end

				local row = Components.create("Frame", {
					Size = UDim2.new(1, 0, 0, 76),
					BackgroundColor3 = Theme.color.surfaceAlt,
					BorderSizePixel = 0,
					Parent = self._listingsScroll,
				}, {
					Components.corner(Theme.radius.md),
					Components.stroke(),
					Components.padding(Theme.pad.sm),
				})

				Components.CardTile(def, nil, {
					Size = UDim2.fromOffset(52, 60),
					Parent = row,
				})

				Components.Label(def.name, {
					Position = UDim2.fromOffset(62, 4),
					Size = UDim2.new(1, -160, 0, 22),
					Font = Theme.font.bodyBold,
					Parent = row,
				})

				Components.Label(tostring(listing.price) .. " pièces", {
					Position = UDim2.fromOffset(62, 30),
					Size = UDim2.new(1, -160, 0, 20),
					dim = true,
					TextSize = Theme.text.sm,
					Parent = row,
				})

				if listing.sellerUserId == Players.LocalPlayer.UserId then
					Components.Button({
						text = "Annuler",
						variant = "danger",
						Size = UDim2.fromOffset(90, 36),
						Position = UDim2.new(1, -98, 0.5, -18),
						Parent = row,
						onClick = function()
							Market:Cancel(listing.id)
								:andThen(function(ok)
									Dock:Toast(
										ok and "Annonce retirée." or "Échec.",
										ok and Theme.color.success or Theme.color.danger
									)
									self:_refreshListings()
								end)
								:catch(function()
									Dock:Toast("Erreur lors de l'annulation.", Theme.color.danger)
								end)
						end,
					})
				else
					Components.Button({
						text = "Acheter",
						variant = "primary",
						Size = UDim2.fromOffset(90, 36),
						Position = UDim2.new(1, -98, 0.5, -18),
						Parent = row,
						onClick = function()
							Market:Buy(listing.id)
								:andThen(function(ok)
									Dock:Toast(
										ok and "Achat réussi !" or "Achat impossible (pièces ?).",
										ok and Theme.color.success or Theme.color.danger
									)
									self:_refreshListings()
								end)
								:catch(function()
									Dock:Toast("Erreur lors de l'achat.", Theme.color.danger)
								end)
						end,
					})
				end
			end
		end)
		:catch(function()
			Dock:Toast("Impossible de charger les annonces.", Theme.color.danger)
		end)
end

function MarketController:_refreshOwnedCards()
	clearChildren(self._ownedScroll)
	if not self._profile then
		return
	end
	local owned = self._profile.cards or {}
	local hasAny = false
	for cardId, entry in owned do
		local def = self._idx and self._idx[cardId]
		if not def then
			continue
		end
		hasAny = true
		local isSelected = self._selectedCardId == cardId
		Components.CardTile(def, entry.count, {
			Size = UDim2.fromOffset(90, 118),
			Parent = self._ownedScroll,
			onClick = function()
				self._selectedCardId = cardId
				self:_refreshOwnedCards()
			end,
		})
		-- Highlight selected card with accent stroke overlay
		if isSelected then
			local tile = self._ownedScroll:GetChildren()[#self._ownedScroll:GetChildren()]
			if tile and tile:IsA("Frame") then
				Components.stroke(Theme.color.accent, 3).Parent = tile
			end
		end
	end
	if not hasAny then
		Components.Label("Aucune carte possédée.", {
			dim = true,
			Parent = self._ownedScroll,
		})
	end
end

-- ── Trade helpers ─────────────────────────────────────────────────────────────

function MarketController:_updateTradeStatus(text)
	if self._tradeStatus then
		self._tradeStatus.Text = text
	end
end

function MarketController:_setOfferSectionVisible(visible)
	if self._offerSection then
		self._offerSection.Visible = visible
	end
end

function MarketController:_refreshOfferCards()
	clearChildren(self._offerScroll)
	if not self._profile then
		return
	end
	local owned = self._profile.cards or {}
	for cardId, entry in owned do
		local def = self._idx and self._idx[cardId]
		if not def then
			continue
		end
		local isSelected = self._selectedOfferCards and self._selectedOfferCards[cardId]
		Components.CardTile(def, entry.count, {
			Size = UDim2.fromOffset(72, 96),
			Parent = self._offerScroll,
			onClick = function()
				if not self._selectedOfferCards then
					self._selectedOfferCards = {}
				end
				if self._selectedOfferCards[cardId] then
					self._selectedOfferCards[cardId] = nil
				else
					self._selectedOfferCards[cardId] = true
				end
				self:_refreshOfferCards()
			end,
		})
		-- Highlight selected offer cards
		if isSelected then
			local children = self._offerScroll:GetChildren()
			local tile = children[#children]
			if tile and tile:IsA("Frame") then
				Components.stroke(Theme.color.accent2, 3).Parent = tile
			end
		end
	end
end

function MarketController:_refreshPlayers()
	clearChildren(self._playersScroll)
	local localPlayer = Players.LocalPlayer
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		local row = Components.create("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = Theme.color.surfaceAlt,
			BorderSizePixel = 0,
			Parent = self._playersScroll,
		}, {
			Components.corner(Theme.radius.md),
			Components.stroke(),
			Components.padding(Theme.pad.sm),
		})

		Components.Label(player.DisplayName, {
			Size = UDim2.new(1, -130, 0, 30),
			Font = Theme.font.bodyBold,
			Parent = row,
		})

		Components.Button({
			text = "Proposer un échange",
			variant = "secondary",
			Size = UDim2.fromOffset(160, 34),
			Position = UDim2.new(1, -168, 0.5, -17),
			Parent = row,
			onClick = function()
				local Trade = Knit.GetService("TradeService")
				local Dock = Knit.GetController("DockController")
				Trade:Propose(player.UserId)
					:andThen(function(sessionId)
						if sessionId then
							self._currentSessionId = sessionId
							self._selectedOfferCards = {}
							self:_updateTradeStatus("Échange proposé…")
							self:_setOfferSectionVisible(true)
							self:_refreshOfferCards()
							Dock:Toast("Échange proposé.", Theme.color.success)
						else
							Dock:Toast("Impossible de proposer.", Theme.color.danger)
						end
					end)
					:catch(function()
						Dock:Toast("Erreur lors de la proposition.", Theme.color.danger)
					end)
			end,
		})
	end
	if #Players:GetPlayers() <= 1 then
		Components.Label("Aucun autre joueur en ligne.", {
			dim = true,
			Parent = self._playersScroll,
		})
	end
end

-- ── Panel build ───────────────────────────────────────────────────────────────

function MarketController:_build(content)
	local idx = Catalog.index(Cards)
	self._idx = idx

	-- ── Tab toggle bar ────────────────────────────────────────────────────────

	local tabBar = Components.create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.color.surfaceAlt,
		BorderSizePixel = 0,
		Parent = content,
	}, {
		Components.corner(Theme.radius.md),
		Components.stroke(),
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.xs),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.pad.xs),
			PaddingRight = UDim.new(0, Theme.pad.xs),
		}),
	})

	-- Two sub-section containers (mutually exclusive visibility)
	local marketContainer = Components.create("Frame", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Visible = true,
		Parent = content,
	})
	self._marketContainer = marketContainer

	local tradeContainer = Components.create("Frame", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = content,
	})
	self._tradeContainer = tradeContainer

	local tabMarket = Components.Button({
		text = "Marché",
		variant = "primary",
		Size = UDim2.fromOffset(130, 34),
		LayoutOrder = 1,
		Parent = tabBar,
		onClick = function()
			marketContainer.Visible = true
			tradeContainer.Visible = false
		end,
	})
	local _ = tabMarket -- referenced but not further used

	Components.Button({
		text = "Échange",
		variant = "secondary",
		Size = UDim2.fromOffset(130, 34),
		LayoutOrder = 2,
		Parent = tabBar,
		onClick = function()
			marketContainer.Visible = false
			tradeContainer.Visible = true
		end,
	})

	-- ── Sub-section A: Marché ─────────────────────────────────────────────────

	-- Sell form
	local sellPanel = Components.create("Frame", {
		Size = UDim2.new(1, 0, 0, 180),
		BackgroundColor3 = Theme.color.surfaceAlt,
		BorderSizePixel = 0,
		Parent = marketContainer,
	}, {
		Components.corner(Theme.radius.md),
		Components.stroke(),
		Components.padding(Theme.pad.sm),
	})

	Components.Heading("Vendre une carte", {
		TextSize = Theme.text.md,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = sellPanel,
	})

	local ownedScroll = Components.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color.stroke,
		Parent = sellPanel,
	}, {
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.pad.xs),
			PaddingRight = UDim.new(0, Theme.pad.xs),
		}),
	})
	self._ownedScroll = ownedScroll

	local sellRow = Components.create("Frame", {
		Position = UDim2.new(0, 0, 1, -42),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = sellPanel,
	}, {
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local priceBox = Components.create("TextBox", {
		PlaceholderText = "Prix",
		Text = "",
		ClearTextOnFocus = false,
		Font = Theme.font.body,
		TextSize = Theme.text.md,
		TextColor3 = Theme.color.text,
		BackgroundColor3 = Theme.color.surfaceAlt,
		Size = UDim2.fromOffset(110, 36),
		LayoutOrder = 1,
		Parent = sellRow,
	}, {
		Components.corner(Theme.radius.md),
		Components.padding(Theme.pad.sm),
	})
	self._priceBox = priceBox

	Components.Button({
		text = "Mettre en vente",
		variant = "primary",
		Size = UDim2.fromOffset(160, 36),
		LayoutOrder = 2,
		Parent = sellRow,
		onClick = function()
			local Market = Knit.GetService("MarketService")
			local Dock = Knit.GetController("DockController")
			local price = tonumber(priceBox.Text)
			if not price or price <= 0 then
				Dock:Toast("Prix invalide.", Theme.color.warning)
				return
			end
			if not self._selectedCardId then
				Dock:Toast("Sélectionne une carte.", Theme.color.warning)
				return
			end
			Market:List(self._selectedCardId, price)
				:andThen(function(listingId)
					if listingId then
						Dock:Toast("Carte mise en vente !", Theme.color.success)
						self._selectedCardId = nil
						priceBox.Text = ""
						self:_refreshOwnedCards()
						self:_refreshListings()
					else
						Dock:Toast("Échec de la mise en vente.", Theme.color.danger)
					end
				end)
				:catch(function()
					Dock:Toast("Erreur lors de la mise en vente.", Theme.color.danger)
				end)
		end,
	})

	-- Listings section
	Components.Heading("Annonces", {
		TextSize = Theme.text.md,
		Position = UDim2.fromOffset(0, 186),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = marketContainer,
	})

	local listingsScroll = Components.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 218),
		Size = UDim2.new(1, 0, 1, -218),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.color.stroke,
		Parent = marketContainer,
	}, {
		Components.create("UIListLayout", {
			Padding = UDim.new(0, Theme.pad.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingTop = UDim.new(0, Theme.pad.xs),
			PaddingBottom = UDim.new(0, Theme.pad.xs),
		}),
	})
	self._listingsScroll = listingsScroll

	-- ── Sub-section B: Échange ────────────────────────────────────────────────

	Components.Heading("Joueurs en ligne", {
		TextSize = Theme.text.md,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = tradeContainer,
	})

	local playersScroll = Components.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.color.stroke,
		Parent = tradeContainer,
	}, {
		Components.create("UIListLayout", {
			Padding = UDim.new(0, Theme.pad.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingTop = UDim.new(0, Theme.pad.xs),
			PaddingBottom = UDim.new(0, Theme.pad.xs),
		}),
	})
	self._playersScroll = playersScroll

	-- Status label
	local tradeStatus = Components.Label("Aucun échange en cours.", {
		dim = true,
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = tradeContainer,
	})
	self._tradeStatus = tradeStatus

	-- Offer editor (only visible once a session exists)
	local offerSection = Components.create("Frame", {
		Position = UDim2.fromOffset(0, 188),
		Size = UDim2.new(1, 0, 1, -188),
		BackgroundColor3 = Theme.color.surfaceAlt,
		BorderSizePixel = 0,
		Visible = false,
		Parent = tradeContainer,
	}, {
		Components.corner(Theme.radius.md),
		Components.stroke(),
		Components.padding(Theme.pad.sm),
	})
	self._offerSection = offerSection

	Components.Heading("Mon offre", {
		TextSize = Theme.text.md,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = offerSection,
	})

	-- Coins input
	local coinsBox = Components.create("TextBox", {
		PlaceholderText = "Pièces à offrir",
		Text = "",
		ClearTextOnFocus = false,
		Font = Theme.font.body,
		TextSize = Theme.text.md,
		TextColor3 = Theme.color.text,
		BackgroundColor3 = Theme.color.surfaceAlt,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(180, 36),
		Parent = offerSection,
	}, {
		Components.corner(Theme.radius.md),
		Components.padding(Theme.pad.sm),
	})
	self._coinsBox = coinsBox

	-- Card picker for offer
	Components.Label("Cartes à offrir :", {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 20),
		dim = true,
		TextSize = Theme.text.sm,
		Parent = offerSection,
	})

	local offerScroll = Components.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color.stroke,
		Parent = offerSection,
	}, {
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Components.create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.pad.xs),
			PaddingRight = UDim.new(0, Theme.pad.xs),
		}),
	})
	self._offerScroll = offerScroll

	-- Action buttons
	local btnRow = Components.create("Frame", {
		Position = UDim2.new(0, 0, 1, -46),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = offerSection,
	}, {
		Components.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.pad.sm),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	Components.Button({
		text = "Définir l'offre",
		variant = "secondary",
		Size = UDim2.fromOffset(130, 36),
		LayoutOrder = 1,
		Parent = btnRow,
		onClick = function()
			local Trade = Knit.GetService("TradeService")
			local Dock = Knit.GetController("DockController")
			if not self._currentSessionId then
				Dock:Toast("Aucun échange en cours.", Theme.color.warning)
				return
			end
			local cardIdsList = {}
			if self._selectedOfferCards then
				for cardId in self._selectedOfferCards do
					table.insert(cardIdsList, cardId)
				end
			end
			local coins = tonumber(coinsBox.Text) or 0
			Trade:SetOffer(self._currentSessionId, { cardIds = cardIdsList, coins = coins })
				:andThen(function(ok)
					if ok then
						self:_updateTradeStatus("Offre définie.")
						Dock:Toast("Offre définie.", Theme.color.success)
					else
						Dock:Toast("Échec de la définition de l'offre.", Theme.color.danger)
					end
				end)
				:catch(function()
					Dock:Toast("Erreur lors de la définition de l'offre.", Theme.color.danger)
				end)
		end,
	})

	Components.Button({
		text = "Confirmer",
		variant = "primary",
		Size = UDim2.fromOffset(110, 36),
		LayoutOrder = 2,
		Parent = btnRow,
		onClick = function()
			local Trade = Knit.GetService("TradeService")
			local Dock = Knit.GetController("DockController")
			if not self._currentSessionId then
				Dock:Toast("Aucun échange en cours.", Theme.color.warning)
				return
			end
			Trade:Confirm(self._currentSessionId)
				:andThen(function(ok)
					if ok then
						self:_updateTradeStatus("Échange confirmé.")
						self._currentSessionId = nil
						self._selectedOfferCards = nil
						self:_setOfferSectionVisible(false)
						Dock:Toast("Échange confirmé !", Theme.color.success)
					else
						Dock:Toast("Confirmation impossible.", Theme.color.danger)
					end
				end)
				:catch(function()
					Dock:Toast("Erreur lors de la confirmation.", Theme.color.danger)
				end)
		end,
	})

	Components.Button({
		text = "Annuler",
		variant = "danger",
		Size = UDim2.fromOffset(90, 36),
		LayoutOrder = 3,
		Parent = btnRow,
		onClick = function()
			local Trade = Knit.GetService("TradeService")
			local Dock = Knit.GetController("DockController")
			if not self._currentSessionId then
				Dock:Toast("Aucun échange en cours.", Theme.color.warning)
				return
			end
			Trade:Cancel(self._currentSessionId)
				:andThen(function(ok)
					if ok then
						self:_updateTradeStatus("Échange annulé.")
						self._currentSessionId = nil
						self._selectedOfferCards = nil
						self:_setOfferSectionVisible(false)
						Dock:Toast("Échange annulé.", Theme.color.warning)
					else
						Dock:Toast("Impossible d'annuler.", Theme.color.danger)
					end
				end)
				:catch(function()
					Dock:Toast("Erreur lors de l'annulation.", Theme.color.danger)
				end)
		end,
	})
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function MarketController:KnitInit()
	local Dock = Knit.GetController("DockController")
	Dock:Register({
		id = "market",
		label = "Marché",
		order = 50,
		build = function(content)
			self:_build(content)
		end,
		onOpen = function()
			local Data = Knit.GetService("DataService")
			Data:GetProfile()
				:andThen(function(profile)
					if profile then
						self._profile = profile
					end
					self:_refreshOwnedCards()
					self:_refreshListings()
					self:_refreshPlayers()
				end)
				:catch(function()
					self:_refreshListings()
					self:_refreshPlayers()
				end)
		end,
	})
end

function MarketController:KnitStart()
	-- Keep own profile in sync
	local Data = Knit.GetService("DataService")
	Data.Updated:Connect(function(profile)
		self._profile = profile
	end)

	-- Rebuild players list on join/leave
	Players.PlayerAdded:Connect(function()
		if self._playersScroll then
			self:_refreshPlayers()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if self._playersScroll then
			self:_refreshPlayers()
		end
	end)
end

return MarketController
