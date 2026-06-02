--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)

local StealController = Knit.CreateController({ Name = "StealController" })

-- Map service reason codes to French messages.
local REASON_FR = {
	self = "C'est toi-même",
	offline = "Joueur hors-ligne",
	empty = "Aucune carte à voler",
	no_cards = "Aucune carte à voler",
	shielded = "Cible protégée par un bouclier",
	not_loaded = "Profil non chargé",
}

local function formatRemaining(seconds: number): string
	if seconds >= 3600 then
		return string.format(
			"%dh %dm",
			math.floor(seconds / 3600),
			math.floor((seconds % 3600) / 60)
		)
	elseif seconds >= 60 then
		return string.format("%dm %ds", math.floor(seconds / 60), math.floor(seconds % 60))
	end
	return string.format("%ds", math.floor(seconds))
end

function StealController:KnitInit()
	local Dock = Knit.GetController("DockController")

	-- Shield label reference – populated during build, refreshed from multiple places.
	local shieldLabel = nil :: TextLabel?

	local function refreshShield()
		local Shield = Knit.GetService("ShieldService")
		Shield:GetRemaining()
			:andThen(function(remaining: number)
				if not shieldLabel then
					return
				end
				if remaining and remaining > 0 then
					shieldLabel.Text = "Bouclier : actif (" .. formatRemaining(remaining) .. ")"
					shieldLabel.TextColor3 = Theme.color.success
				else
					shieldLabel.Text = "Bouclier : inactif"
					shieldLabel.TextColor3 = Theme.color.textDim
				end
			end)
			:catch(function() end)
	end

	local playerList = nil :: ScrollingFrame?

	local function refreshPlayers()
		if not playerList then
			return
		end
		-- Clear non-layout children.
		for _, ch in playerList:GetChildren() do
			if not ch:IsA("UILayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end

		local local_player = Players.LocalPlayer
		local others = {}
		for _, p in Players:GetPlayers() do
			if p ~= local_player then
				table.insert(others, p)
			end
		end

		if #others == 0 then
			Components.Label("Aucun autre joueur en ligne", {
				dim = true,
				TextWrapped = true,
				LayoutOrder = 1,
				Parent = playerList,
			})
			return
		end

		for i, player in others do
			local row = Components.create("Frame", {
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Theme.color.surfaceAlt,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = playerList,
			}, {
				Components.corner(Theme.radius.md),
				Components.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, Theme.pad.sm),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Components.create("UIPadding", {
					PaddingLeft = UDim.new(0, Theme.pad.md),
					PaddingRight = UDim.new(0, Theme.pad.md),
					PaddingTop = UDim.new(0, Theme.pad.xs),
					PaddingBottom = UDim.new(0, Theme.pad.xs),
				}),
			})

			Components.Label(player.DisplayName, {
				Size = UDim2.new(1, -110, 0, 28),
				LayoutOrder = 1,
				Parent = row,
			})

			local capturedUserId = player.UserId
			Components.Button({
				text = "Voler",
				variant = "danger",
				Size = UDim2.fromOffset(100, 34),
				LayoutOrder = 2,
				Parent = row,
				onClick = function()
					local Steal = Knit.GetService("StealService")
					Steal:Attempt(capturedUserId)
						:andThen(function(result)
							if result and result.success then
								local cardName = "?"
								if result.cardId then
									local Cards = require(ReplicatedStorage.Shared.Config.Cards)
									local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)
									local idxMap = Catalog.index(Cards)
									local def = idxMap[result.cardId]
									if def then
										cardName = def.name
									end
								end
								Dock:Toast("Carte volée : " .. cardName, Theme.color.success)
								refreshPlayers()
							else
								local reason = result and result.reason or ""
								local msg = REASON_FR[reason] or "Échec"
								Dock:Toast(msg, Theme.color.danger)
							end
						end)
						:catch(function()
							Dock:Toast("Échec", Theme.color.danger)
						end)
				end,
			})
		end
	end

	Dock:Register({
		id = "steal",
		label = "Voler",
		order = 20,
		build = function(content)
			-- ── Shield section ──────────────────────────────────────────────────
			local shieldSection = Components.create("Frame", {
				Size = UDim2.new(1, 0, 0, 100),
				BackgroundColor3 = Theme.color.surfaceAlt,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Parent = content,
			}, {
				Components.corner(Theme.radius.md),
				Components.stroke(),
				Components.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, Theme.pad.sm),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Components.create("UIPadding", {
					PaddingLeft = UDim.new(0, Theme.pad.md),
					PaddingRight = UDim.new(0, Theme.pad.md),
					PaddingTop = UDim.new(0, Theme.pad.sm),
					PaddingBottom = UDim.new(0, Theme.pad.sm),
				}),
			})

			shieldLabel = Components.Label("Bouclier : …", {
				dim = true,
				LayoutOrder = 1,
				Parent = shieldSection,
			})

			Components.Button({
				text = "Réactiver (500)",
				variant = "secondary",
				Size = UDim2.new(1, 0, 0, 36),
				LayoutOrder = 2,
				Parent = shieldSection,
				onClick = function()
					local Shield = Knit.GetService("ShieldService")
					Shield:Reactivate()
						:andThen(function(ok: boolean)
							if ok then
								Dock:Toast("Bouclier activé !", Theme.color.success)
							else
								Dock:Toast(
									"Impossible de réactiver le bouclier",
									Theme.color.danger
								)
							end
							refreshShield()
						end)
						:catch(function()
							Dock:Toast("Erreur lors de la réactivation", Theme.color.danger)
						end)
				end,
			})

			-- ── Player list ─────────────────────────────────────────────────────
			Components.Heading("Joueurs en ligne", {
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 2,
				Parent = content,
			})

			playerList = Components.ScrollList({
				Size = UDim2.new(1, 0, 1, -150),
				gap = Theme.pad.sm,
				padding = Theme.pad.xs,
				Parent = content,
			})
			playerList.LayoutOrder = 3

			Components.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, Theme.pad.sm),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}).Parent =
				content

			-- Listen for players joining/leaving (connect once in build).
			Players.PlayerAdded:Connect(function()
				refreshPlayers()
			end)
			Players.PlayerRemoving:Connect(function()
				refreshPlayers()
			end)

			-- Subscribe to profile updates to refresh the shield.
			local Data = Knit.GetService("DataService")
			Data.Updated:Connect(function()
				refreshShield()
			end)

			refreshShield()
			refreshPlayers()
		end,
		onOpen = function()
			refreshShield()
			refreshPlayers()
		end,
	})
end

function StealController:KnitStart() end

return StealController
