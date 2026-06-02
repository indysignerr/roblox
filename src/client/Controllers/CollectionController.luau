--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)

local CollectionController = Knit.CreateController({ Name = "CollectionController" })

-- Build the card index once (pure data, safe at require time).
local idx = Catalog.index(Cards)
local nations = Catalog.nations(Cards)

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Clear children of a ScrollingFrame/Frame, leaving UILayout and UIPadding intact.
local function clearChildren(parent: Instance)
	for _, ch in parent:GetChildren() do
		if not ch:IsA("UILayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

-- ── Build ─────────────────────────────────────────────────────────────────────

function CollectionController:KnitInit()
	local Dock = Knit.GetController("DockController")

	-- Refs populated during build(), used by refresh.
	local grid = nil
	local dailyBtn = nil
	local flashBtn = nil
	local emptyLabel = nil

	-- Refresh the card grid from a profile snapshot.
	local function refreshGrid(profile)
		if not grid then
			return
		end
		clearChildren(grid)

		local hasCards = false
		for cardId, owned in profile.cards do
			local def = idx[cardId]
			if def then
				hasCards = true
				Components.CardTile(def, owned.count, { Parent = grid })
			end
		end

		if emptyLabel then
			emptyLabel.Visible = not hasCards
		end
	end

	-- Update daily button enabled state.
	local function refreshDailyBtn(Pack)
		if not dailyBtn then
			return
		end
		Pack:CanClaimDaily()
			:andThen(function(canClaim)
				dailyBtn.BackgroundTransparency = canClaim and 0 or 0.45
				dailyBtn.Active = canClaim
			end)
			:catch(function() end)
	end

	-- Update flash button enabled state.
	local function refreshFlashBtn(Pack)
		if not flashBtn then
			return
		end
		Pack:IsFlashActive()
			:andThen(function(active)
				flashBtn.BackgroundTransparency = active and 0 or 0.45
				flashBtn.Active = active
			end)
			:catch(function() end)
	end

	Dock:Register({
		id = "collection",
		label = "Cartes",
		order = 10,

		build = function(content)
			local Data = Knit.GetService("DataService")
			local Pack = Knit.GetService("PackService")

			-- ── Top section: pack controls ──────────────────────────────────
			local topBar = Components.create("Frame", {
				Name = "PackControls",
				Size = UDim2.new(1, 0, 0, 96),
				BackgroundTransparency = 1,
				Parent = content,
			}, {
				Components.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, Theme.pad.sm),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})

			-- Row 1: daily + flash buttons.
			local btnRow = Components.create("Frame", {
				Name = "BtnRow",
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Parent = topBar,
			}, {
				Components.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, Theme.pad.sm),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})

			dailyBtn = Components.Button({
				text = "Pack quotidien",
				variant = "primary",
				Size = UDim2.new(0.5, -Theme.pad.sm / 2, 1, 0),
				LayoutOrder = 1,
				Parent = btnRow,
				onClick = function()
					Pack:OpenDaily()
						:andThen(function(cardId)
							if cardId and idx[cardId] then
								Dock:Toast(
									"Nouvelle carte : " .. idx[cardId].name,
									Theme.color.accent2
								)
							else
								Dock:Toast("Indisponible", Theme.color.danger)
							end
							-- Refresh availability after opening.
							refreshDailyBtn(Pack)
						end)
						:catch(function()
							Dock:Toast("Indisponible", Theme.color.danger)
						end)
				end,
			})

			flashBtn = Components.Button({
				text = "Pack Flash",
				variant = "secondary",
				Size = UDim2.new(0.5, -Theme.pad.sm / 2, 1, 0),
				LayoutOrder = 2,
				Parent = btnRow,
				onClick = function()
					Pack:OpenFlash()
						:andThen(function(cardId)
							if cardId and idx[cardId] then
								Dock:Toast(
									"Nouvelle carte : " .. idx[cardId].name,
									Theme.color.accent2
								)
							else
								Dock:Toast("Indisponible", Theme.color.danger)
							end
						end)
						:catch(function()
							Dock:Toast("Indisponible", Theme.color.danger)
						end)
				end,
			})

			-- Row 2: nation picker (horizontal scroll).
			local nationScroll = Components.ScrollList({
				Size = UDim2.new(1, 0, 0, 40),
				gap = Theme.pad.sm,
				padding = 0,
				Parent = topBar,
			})
			nationScroll.ScrollingDirection = Enum.ScrollingDirection.X
			nationScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
			nationScroll.CanvasSize = UDim2.new()
			nationScroll.LayoutOrder = 2

			-- Change the list layout inside to horizontal.
			for _, ch in nationScroll:GetChildren() do
				if ch:IsA("UIListLayout") then
					ch.FillDirection = Enum.FillDirection.Horizontal
					ch.VerticalAlignment = Enum.VerticalAlignment.Center
				end
			end

			for i, nation in nations do
				Components.Button({
					text = nation,
					variant = "ghost",
					Size = UDim2.fromOffset(100, 32),
					LayoutOrder = i,
					Parent = nationScroll,
					onClick = function()
						Pack:OpenNation(nation)
							:andThen(function(cardId)
								if cardId and idx[cardId] then
									Dock:Toast(
										"Nouvelle carte : " .. idx[cardId].name,
										Theme.color.accent2
									)
								else
									Dock:Toast("Indisponible", Theme.color.danger)
								end
							end)
							:catch(function()
								Dock:Toast("Indisponible", Theme.color.danger)
							end)
					end,
				})
			end

			-- ── Collection heading ──────────────────────────────────────────
			Components.Heading("Ma collection", {
				Position = UDim2.fromOffset(0, 104),
				Size = UDim2.new(1, 0, 0, 28),
				Parent = content,
			})

			-- ── Card grid ──────────────────────────────────────────────────
			grid = Components.Grid({
				Position = UDim2.fromOffset(0, 138),
				Size = UDim2.new(1, 0, 1, -138),
				cell = Vector2.new(110, 148),
				gap = Theme.pad.sm,
				Parent = content,
			})

			emptyLabel = Components.Label("Aucune carte pour l'instant", {
				dim = true,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = grid,
			})
			emptyLabel.Visible = false

			-- Initial load.
			Data:GetProfile()
				:andThen(function(profile)
					if profile then
						refreshGrid(profile)
					end
				end)
				:catch(function() end)

			-- Keep grid in sync when profile changes (pack openings, etc.).
			Data.Updated:Connect(function(profile)
				refreshGrid(profile)
			end)

			-- Initial button states.
			refreshDailyBtn(Pack)
			refreshFlashBtn(Pack)
		end,

		onOpen = function()
			-- Re-check button availability each time the panel opens.
			local Pack = Knit.GetService("PackService")
			refreshDailyBtn(Pack)
			refreshFlashBtn(Pack)

			-- Also refresh the grid in case the profile changed while panel was closed.
			local Data = Knit.GetService("DataService")
			Data:GetProfile()
				:andThen(function(profile)
					if profile then
						refreshGrid(profile)
					end
				end)
				:catch(function() end)
		end,
	})
end

function CollectionController:KnitStart() end

return CollectionController
