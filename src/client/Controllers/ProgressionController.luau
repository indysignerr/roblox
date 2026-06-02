--!nonstrict
-- ProgressionController: daily streak claim, zone unlocks, and nation score readout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local ZONE_ORDER = { "stadium", "vip", "legends" }

local ProgressionController = Knit.CreateController({
	Name = "ProgressionController",
})

function ProgressionController:KnitInit()
	local Dock = Knit.GetController("DockController")

	Dock:Register({
		id = "progression",
		label = "Progression",
		order = 80,

		build = function(content)
			local Prog = Knit.GetService("ProgressionService")
			local Data = Knit.GetService("DataService")
			local refresh

			-- ── Root scroll list ────────────────────────────────────────────
			local scroll = Components.ScrollList({
				Size = UDim2.fromScale(1, 1),
				padding = Theme.pad.md,
				gap = Theme.pad.lg,
				Parent = content,
			})

			-- ── Section 1 — Récompense quotidienne ──────────────────────────
			local dailyPanel = Components.Panel({
				Size = UDim2.new(1, 0, 0, 110),
				color = Theme.color.surfaceAlt,
				Parent = scroll,
			})
			dailyPanel.LayoutOrder = 1

			Components.padding(Theme.pad.md).Parent = dailyPanel
			Components.listLayout({ gap = Theme.pad.sm }).Parent = dailyPanel

			Components.Heading("Récompense quotidienne", {
				TextSize = Theme.text.md,
				Parent = dailyPanel,
			})

			local streakLabel = Components.Label("Série actuelle : 0", {
				dim = true,
				LayoutOrder = 1,
				Parent = dailyPanel,
			})

			Components.Button({
				text = "Réclamer",
				variant = "primary",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 44),
				Parent = dailyPanel,
				onClick = function()
					Prog:ClaimDaily()
						:andThen(function(res)
							if res and res.claimed then
								Dock:Toast(
									"+"
										.. tostring(res.reward)
										.. " · Série "
										.. tostring(res.streak),
									Theme.color.success
								)
							else
								Dock:Toast("Déjà réclamé aujourd'hui.", Theme.color.warning)
							end
							refresh()
						end)
						:catch(function(err)
							Dock:Toast("Erreur : " .. tostring(err), Theme.color.danger)
						end)
				end,
			})

			-- ── Section 2 — Zones à débloquer ───────────────────────────────
			local zonesPanel = Components.Panel({
				Size = UDim2.new(1, 0, 0, 160),
				color = Theme.color.surfaceAlt,
				Parent = scroll,
			})
			zonesPanel.LayoutOrder = 2
			zonesPanel.AutomaticSize = Enum.AutomaticSize.Y

			Components.padding(Theme.pad.md).Parent = zonesPanel
			Components.listLayout({ gap = Theme.pad.sm }).Parent = zonesPanel

			Components.Heading("Zones à débloquer", {
				TextSize = Theme.text.md,
				LayoutOrder = 0,
				Parent = zonesPanel,
			})

			local zoneList = Components.create("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Parent = zonesPanel,
			})
			Components.listLayout({ gap = Theme.pad.sm }).Parent = zoneList

			-- ── Section 3 — Score nation ─────────────────────────────────────
			local scorePanel = Components.Panel({
				Size = UDim2.new(1, 0, 0, 60),
				color = Theme.color.surfaceAlt,
				Parent = scroll,
			})
			scorePanel.LayoutOrder = 3

			Components.padding(Theme.pad.md).Parent = scorePanel
			Components.listLayout({ gap = Theme.pad.sm }).Parent = scorePanel

			local scoreLabel = Components.Label("Score nation : —", {
				LayoutOrder = 0,
				Parent = scorePanel,
			})

			-- ── refresh() ────────────────────────────────────────────────────
			refresh = function()
				Data:GetProfile()
					:andThen(function(profile)
						-- Section 1 : streak
						local streakVal = 0
						if profile and profile.streak then
							streakVal = profile.streak.current or 0
						end
						streakLabel.Text = "Série actuelle : " .. tostring(streakVal)

						-- Section 2 : zones (clear children, keep UILayout/UIPadding)
						for _, ch in zoneList:GetChildren() do
							if not ch:IsA("UILayout") and not ch:IsA("UIPadding") then
								ch:Destroy()
							end
						end

						local unlockedZones = (profile and profile.unlockedZones) or {}

						for idx, zoneId in ZONE_ORDER do
							local zone = ZoneConfig[zoneId]
							if not zone then
								continue
							end

							local row = Components.create("Frame", {
								Size = UDim2.new(1, 0, 0, 44),
								BackgroundTransparency = 1,
								LayoutOrder = idx,
								Parent = zoneList,
							})
							Components.listLayout({
								horizontal = true,
								gap = Theme.pad.sm,
							}).Parent =
								row
							Components.create("UIPadding", {
								PaddingTop = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 4),
							}).Parent =
								row

							Components.Label(zone.name, {
								Size = UDim2.fromScale(0.55, 1),
								LayoutOrder = 1,
								Parent = row,
							})

							if unlockedZones[zoneId] then
								Components.Label("Débloqué", {
									dim = true,
									Size = UDim2.fromScale(0.45, 1),
									TextXAlignment = Enum.TextXAlignment.Right,
									LayoutOrder = 2,
									Parent = row,
								})
							else
								local btnLabel = "Débloquer (" .. tostring(zone.cost) .. ")"
								local capturedZoneId = zoneId
								local capturedZoneName = zone.name
								Components.Button({
									text = btnLabel,
									variant = "secondary",
									Size = UDim2.fromScale(0.45, 1),
									LayoutOrder = 2,
									Parent = row,
									onClick = function()
										Prog:UnlockZone(capturedZoneId)
											:andThen(function(ok)
												if ok then
													Dock:Toast(
														capturedZoneName .. " débloqué !",
														Theme.color.success
													)
												else
													Dock:Toast(
														"Pièces insuffisantes.",
														Theme.color.danger
													)
												end
												refresh()
											end)
											:catch(function(err)
												Dock:Toast(
													"Erreur : " .. tostring(err),
													Theme.color.danger
												)
											end)
									end,
								})
							end
						end
					end)
					:catch(function()
						streakLabel.Text = "Série actuelle : 0"
					end)

				-- Section 3 : nation score
				Prog:GetNationScore()
					:andThen(function(score)
						scoreLabel.Text = "Score nation : " .. tostring(score or 0)
					end)
					:catch(function()
						scoreLabel.Text = "Score nation : —"
					end)
			end

			-- Connect to live updates (once, inside build)
			Data.Updated:Connect(function(_profile)
				refresh()
			end)

			-- Initial population
			refresh()
		end,

		onOpen = function()
			-- refresh() is a local in build, so we rely on Data.Updated + initial build call.
			-- onOpen is provided as a hook for future use.
		end,
	})
end

function ProgressionController:KnitStart() end

return ProgressionController
