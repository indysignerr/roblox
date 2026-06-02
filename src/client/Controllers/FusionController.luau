--!nonstrict
-- FusionController: fuse 5 Rare cards into 1 Epic (80% success; cards consumed even on failure).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Catalog = require(ReplicatedStorage.Shared.Logic.Catalog)

local FusionController = Knit.CreateController({
	Name = "FusionController",
})

function FusionController:KnitInit()
	local Dock = Knit.GetController("DockController")

	-- Pre-build the catalog index once at registration time (pure data, no service calls).
	local idx = Catalog.index(Cards)

	-- State shared between build and onOpen callbacks.
	local countLabel = nil :: TextLabel?
	local fuseBtn = nil :: TextButton?
	local resultArea = nil :: Frame?
	local Data = nil
	local Fusion = nil

	-- Clears and re-populates the result area with a single CardTile for the given def.
	local function showResult(def)
		if not resultArea then
			return
		end
		for _, ch in resultArea:GetChildren() do
			if not ch:IsA("UILayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
		if def then
			Components.CardTile(def, nil, {
				Parent = resultArea,
				Size = UDim2.fromOffset(120, 160),
			})
		end
	end

	-- Counts total owned Rare cards.
	local function countRares(profile)
		if not profile or not profile.cards then
			return 0
		end
		local total = 0
		for cardId, entry in profile.cards do
			local def = idx[cardId]
			if def and def.rarity == "Rare" then
				total = total + (entry.count or 0)
			end
		end
		return total
	end

	-- Updates the Rare count label and button state from a profile snapshot.
	local function applyProfile(profile)
		if not countLabel or not fuseBtn then
			return
		end
		if not profile then
			countLabel.Text = "Chargement…"
			countLabel.TextColor3 = Theme.color.textDim
			fuseBtn.BackgroundColor3 = Theme.color.surfaceAlt
			fuseBtn.TextColor3 = Theme.color.textDim
			return
		end
		local n = countRares(profile)
		local enough = n >= 5
		countLabel.Text = "Cartes Rare : " .. tostring(n) .. " / 5"
		countLabel.TextColor3 = enough and Theme.color.success or Theme.color.textDim
		fuseBtn.BackgroundColor3 = enough and Theme.color.accent or Theme.color.surfaceAlt
		fuseBtn.TextColor3 = enough and Theme.color.bg or Theme.color.textDim
	end

	-- Refreshes the panel from DataService (safe to call at any time after build).
	local function refresh()
		if not Data then
			return
		end
		Data:GetProfile()
			:andThen(function(profile)
				applyProfile(profile)
			end)
			:catch(function()
				applyProfile(nil)
			end)
	end

	Dock:Register({
		id = "fusion",
		label = "Fusion",
		order = 30,

		build = function(content)
			-- Services are safe to resolve here (called after KnitStart).
			Data = Knit.GetService("DataService")
			Fusion = Knit.GetService("FusionService")

			-- Vertical scroll list fills the content frame.
			local list = Components.ScrollList({
				Parent = content,
				gap = Theme.pad.md,
				padding = Theme.pad.md,
			})

			-- ── Rule explanation ────────────────────────────────────────────────
			Components.Label("Combine 5 cartes Rare pour obtenir 1 carte Épique aléatoire.", {
				Parent = list,
				Size = UDim2.new(1, 0, 0, 40),
				TextWrapped = true,
				LayoutOrder = 1,
			})

			Components.Label(
				"⚠ Les cartes sont consommées même en cas d'échec (20% de risque).",
				{
					Parent = list,
					Size = UDim2.new(1, 0, 0, 40),
					TextWrapped = true,
					TextColor3 = Theme.color.warning,
					LayoutOrder = 2,
				}
			)

			-- ── Rare count readout ───────────────────────────────────────────────
			local cLabel = Components.create("TextLabel", {
				Text = "Cartes Rare : … / 5",
				Font = Theme.font.heading,
				TextSize = Theme.text.md,
				TextColor3 = Theme.color.textDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 3,
				Parent = list,
			})
			countLabel = cLabel

			-- ── Progress bar (0–5 Rare cards) ───────────────────────────────────
			local bar = Components.ProgressBar({
				Size = UDim2.new(1, 0, 0, 10),
				color = Theme.color.success,
				Parent = list,
			})
			-- Keep the bar in sync; wrap so we can call it after profile loads.
			local progressBar = bar

			-- ── FUSIONNER button ─────────────────────────────────────────────────
			local btn = Components.Button({
				text = "FUSIONNER",
				variant = "primary",
				Size = UDim2.new(1, 0, 0, 52),
				LayoutOrder = 5,
				Parent = list,
				onClick = function()
					if not Fusion then
						return
					end
					Fusion:Fuse()
						:andThen(function(res)
							if res.success then
								local epicDef = res.outputCardId and idx[res.outputCardId]
								Dock:Toast("Fusion réussie !", Theme.color.success)
								if epicDef then
									showResult(epicDef)
								end
							elseif res.reason == "failed" then
								Dock:Toast("Fusion ratée ! Cartes perdues.", Theme.color.danger)
								showResult(nil)
							elseif res.reason == "not_enough" then
								Dock:Toast("Il faut 5 cartes Rare.", Theme.color.danger)
							else
								Dock:Toast("Erreur : impossible de fusionner.", Theme.color.danger)
							end
							refresh()
						end)
						:catch(function()
							Dock:Toast("Erreur inattendue lors de la fusion.", Theme.color.danger)
							refresh()
						end)
				end,
			})
			fuseBtn = btn

			-- ── Result area ──────────────────────────────────────────────────────
			local rArea = Components.create("Frame", {
				Name = "ResultArea",
				Size = UDim2.new(1, 0, 0, 170),
				BackgroundTransparency = 1,
				LayoutOrder = 6,
				Parent = list,
			}, {
				Components.listLayout({
					horizontal = true,
					hAlign = Enum.HorizontalAlignment.Center,
				}),
			})
			resultArea = rArea

			-- Heading above result (always visible even before first fuse).
			Components.Label("Résultat", {
				dim = true,
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = 7,
				Parent = list,
			})

			-- Connect Data.Updated so the panel stays live.
			Data.Updated:Connect(function(profile)
				applyProfile(profile)
				-- Also refresh progress bar.
				local n = countRares(profile)
				progressBar.set(math.clamp(n / 5, 0, 1))
			end)

			refresh()
		end,

		onOpen = function()
			refresh()
		end,
	})
end

function FusionController:KnitStart() end

return FusionController
