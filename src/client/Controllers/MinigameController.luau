--!nonstrict
-- MinigameController: penalty shootout (pick a direction) + co-op boss battle (chip HP).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local MinigameConfig = require(ReplicatedStorage.Shared.Config.MinigameConfig)

local MinigameController = Knit.CreateController({
	Name = "MinigameController",
})

-- Direction labels for the 5 aim zones.
local DIRS = {
	"Coin haut gauche",
	"Haut centre",
	"Coin haut droit",
	"Bas gauche",
	"Bas droit",
}

local maxHp = MinigameConfig.boss.maxHp

function MinigameController:KnitInit()
	local Dock = Knit.GetController("DockController")
	Dock:Register({
		id = "minigame",
		label = "Mini-jeux",
		order = 60,
		build = function(content)
			local Mini = Knit.GetService("MinigameService")

			-- Outer scroll list so the two sections stack vertically.
			local scroll = Components.ScrollList({
				Size = UDim2.fromScale(1, 1),
				gap = Theme.pad.lg,
				padding = Theme.pad.sm,
				Parent = content,
			})

			-- ── Section 1 : Tirs au but ──────────────────────────────────────────────

			local penaltySection = Components.create("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.color.surfaceAlt,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Parent = scroll,
			}, {
				Components.corner(Theme.radius.md),
				Components.stroke(),
				Components.padding(Theme.pad.md),
				Components.listLayout({ gap = Theme.pad.sm }),
			})

			Components.Heading("Tirs au but", {
				LayoutOrder = 1,
				Parent = penaltySection,
			})

			Components.Label("Choisis une zone et tire !", {
				dim = true,
				LayoutOrder = 2,
				Parent = penaltySection,
			})

			-- Row of 5 direction buttons.
			local btnRow = Components.create("Frame", {
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Parent = penaltySection,
			}, {
				Components.listLayout({ horizontal = true, gap = Theme.pad.xs }),
			})

			-- Result label (shows keeper dive zone after each shot).
			local resultLabel = Components.Label("", {
				dim = true,
				TextWrapped = true,
				LayoutOrder = 4,
				Parent = penaltySection,
			})

			-- Track whether a penalty is in flight to avoid double-clicks.
			local penaltyBusy = false

			for dirIndex = 1, 5 do
				Components.Button({
					text = DIRS[dirIndex],
					variant = "secondary",
					Size = UDim2.fromOffset(0, 44),
					TextSize = 13,
					LayoutOrder = dirIndex,
					Parent = btnRow,
					onClick = function()
						if penaltyBusy then
							return
						end
						penaltyBusy = true
						resultLabel.Text = "Tir en cours…"
						local DockCtrl = Knit.GetController("DockController")
						Mini:PlayPenalty(dirIndex)
							:andThen(function(res)
								penaltyBusy = false
								if res and res.goal then
									DockCtrl:Toast(
										"BUT ! +" .. tostring(res.reward),
										Theme.color.success
									)
								else
									DockCtrl:Toast(
										"Raté… +" .. tostring(res and res.reward or 0),
										Theme.color.warning
									)
								end
								local keeperZone = res and res.keeperDir or 0
								resultLabel.Text = "Le gardien a plongé en zone "
									.. tostring(keeperZone)
							end)
							:catch(function(err)
								penaltyBusy = false
								resultLabel.Text = ""
								DockCtrl:Toast("Erreur : " .. tostring(err), Theme.color.danger)
							end)
					end,
				})
			end

			-- Give each button an equal fractional width (1/5 of the row).
			for _, btn in btnRow:GetChildren() do
				if btn:IsA("TextButton") then
					btn.Size = UDim2.new(0.2, -(Theme.pad.xs * 4 / 5), 0, 44)
				end
			end

			-- ── Section 2 : Boss coopératif ──────────────────────────────────────────

			local bossSection = Components.create("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.color.surfaceAlt,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Parent = scroll,
			}, {
				Components.corner(Theme.radius.md),
				Components.stroke(),
				Components.padding(Theme.pad.md),
				Components.listLayout({ gap = Theme.pad.sm }),
			})

			Components.Heading("Boss coopératif", {
				LayoutOrder = 1,
				Parent = bossSection,
			})

			local bar = Components.ProgressBar({
				color = Theme.color.danger,
				Size = UDim2.new(1, 0, 0, 14),
				alpha = 1,
				LayoutOrder = 2,
				Parent = bossSection,
			})

			local hpLabel = Components.Label(tostring(maxHp) .. " / " .. tostring(maxHp), {
				dim = true,
				LayoutOrder = 3,
				Parent = bossSection,
			})

			local function updateBoss(hp: number)
				local safeHp = math.max(0, hp)
				bar.set(safeHp / maxHp)
				hpLabel.Text = tostring(safeHp) .. " / " .. tostring(maxHp)
			end

			-- Seed on build.
			Mini:GetBoss()
				:andThen(function(boss)
					local hp = (boss and boss.hp) or maxHp
					updateBoss(hp)
				end)
				:catch(function()
					updateBoss(maxHp)
				end)

			Components.Button({
				text = "Attaquer",
				variant = "primary",
				LayoutOrder = 4,
				Parent = bossSection,
				onClick = function()
					local DockCtrl = Knit.GetController("DockController")
					Mini:AttackBoss(250)
						:andThen(function(res)
							if res then
								updateBoss(res.hp)
								if res.dead then
									DockCtrl:Toast("Boss vaincu !", Theme.color.success)
								end
							end
						end)
						:catch(function(err)
							DockCtrl:Toast("Erreur : " .. tostring(err), Theme.color.danger)
						end)
				end,
			})

			-- Store updateBoss so onOpen can re-seed without a second GetBoss call.
			MinigameController._updateBoss = updateBoss
			MinigameController._mini = Mini
		end,
		onOpen = function()
			local mini = MinigameController._mini
			local updateBoss = MinigameController._updateBoss
			if mini and updateBoss then
				mini:GetBoss()
					:andThen(function(boss)
						local hp = (boss and boss.hp) or maxHp
						updateBoss(hp)
					end)
					:catch(function()
						updateBoss(maxHp)
					end)
			end
		end,
	})
end

function MinigameController:KnitStart() end

return MinigameController
