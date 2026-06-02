--!nonstrict
-- TeamController: create/join a team, view roster, leave, and (as Manager) assign roles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)

local TeamController = Knit.CreateController({
	Name = "TeamController",
})

local function translateRole(role: string): string
	if role == "Manager" then
		return "Manager"
	elseif role == "Captain" then
		return "Capitaine"
	end
	return "Joueur"
end

local function clearContent(parent: Instance)
	for _, ch in parent:GetChildren() do
		if not ch:IsA("UILayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

function TeamController:KnitInit()
	local Dock = Knit.GetController("DockController")

	local container: Frame = nil

	local function render(team)
		if not container then
			return
		end
		clearContent(container)

		if team == nil then
			-- ── No team: show create + join forms ────────────────────────────────

			local createSection = Components.create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 108),
				LayoutOrder = 1,
				Parent = container,
			}, {
				Components.listLayout({ gap = Theme.pad.sm }),
			})

			Components.Heading("Créer une équipe", {
				TextSize = Theme.text.md,
				Size = UDim2.new(1, 0, 0, Theme.text.md + 8),
				LayoutOrder = 1,
				Parent = createSection,
			})

			local createBox = Components.create("TextBox", {
				PlaceholderText = "Nom de l'équipe",
				Text = "",
				ClearTextOnFocus = false,
				Font = Theme.font.body,
				TextSize = Theme.text.md,
				TextColor3 = Theme.color.text,
				PlaceholderColor3 = Theme.color.textDim,
				BackgroundColor3 = Theme.color.surfaceAlt,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 2,
				Parent = createSection,
			}, {
				Components.corner(Theme.radius.md),
				Components.padding(Theme.pad.sm),
			})

			Components.Button({
				text = "Créer",
				variant = "primary",
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 3,
				Parent = createSection,
				onClick = function()
					local Team = Knit.GetService("TeamService")
					Team:Create(createBox.Text)
						:andThen(function(id)
							if id then
								Dock:Toast("Équipe créée !", Theme.color.success)
							else
								Dock:Toast("Création impossible.", Theme.color.danger)
							end
						end)
						:catch(function()
							Dock:Toast("Création impossible.", Theme.color.danger)
						end)
				end,
			})

			-- Separator
			Components.create("Frame", {
				BackgroundColor3 = Theme.color.stroke,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				LayoutOrder = 2,
				Parent = container,
			})

			local joinSection = Components.create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 108),
				LayoutOrder = 3,
				Parent = container,
			}, {
				Components.listLayout({ gap = Theme.pad.sm }),
			})

			Components.Heading("Rejoindre une équipe", {
				TextSize = Theme.text.md,
				Size = UDim2.new(1, 0, 0, Theme.text.md + 8),
				LayoutOrder = 1,
				Parent = joinSection,
			})

			local joinBox = Components.create("TextBox", {
				PlaceholderText = "ID de l'équipe",
				Text = "",
				ClearTextOnFocus = false,
				Font = Theme.font.body,
				TextSize = Theme.text.md,
				TextColor3 = Theme.color.text,
				PlaceholderColor3 = Theme.color.textDim,
				BackgroundColor3 = Theme.color.surfaceAlt,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 2,
				Parent = joinSection,
			}, {
				Components.corner(Theme.radius.md),
				Components.padding(Theme.pad.sm),
			})

			Components.Button({
				text = "Rejoindre",
				variant = "secondary",
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 3,
				Parent = joinSection,
				onClick = function()
					local Team = Knit.GetService("TeamService")
					Team:Join(joinBox.Text)
						:andThen(function(ok)
							if ok then
								Dock:Toast("Équipe rejointe !", Theme.color.success)
							else
								Dock:Toast("Impossible de rejoindre.", Theme.color.danger)
							end
						end)
						:catch(function()
							Dock:Toast("Impossible de rejoindre.", Theme.color.danger)
						end)
				end,
			})
		else
			-- ── In a team: show roster + actions ────────────────────────────────

			local myUserId = Players.LocalPlayer.UserId
			local myRole = team.members[myUserId]

			-- Team name heading
			Components.Heading(team.name, {
				LayoutOrder = 1,
				Parent = container,
			})

			-- Invite ID hint
			Components.Label("Partage cet ID pour inviter : " .. tostring(team.id), {
				dim = true,
				TextSize = Theme.text.sm,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, Theme.text.sm + 8),
				LayoutOrder = 2,
				Parent = container,
			})

			-- Capacity hint
			Components.Label("1 Manager · 2 Capitaines · 8 Joueurs", {
				dim = true,
				TextSize = Theme.text.sm,
				Size = UDim2.new(1, 0, 0, Theme.text.sm + 8),
				LayoutOrder = 3,
				Parent = container,
			})

			-- Roster scroll list
			local rosterList = Components.ScrollList({
				Size = UDim2.new(1, 0, 1, -130),
				gap = Theme.pad.sm,
				padding = Theme.pad.sm,
				LayoutOrder = 4,
				Parent = container,
			})

			local rowOrder = 0
			for userId, role in team.members do
				rowOrder += 1

				local isMe = userId == myUserId
				local displayName
				local playerInst = Players:GetPlayerByUserId(userId)
				if playerInst then
					displayName = playerInst.DisplayName
				else
					displayName = "ID " .. tostring(userId)
				end

				local rowHeight = 44
				if myRole == "Manager" and not isMe then
					rowHeight = 96
				end

				local row = Components.create("Frame", {
					BackgroundColor3 = Theme.color.surfaceAlt,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, rowHeight),
					LayoutOrder = rowOrder,
					Parent = rosterList,
				}, {
					Components.corner(Theme.radius.md),
					Components.padding(Theme.pad.sm),
					Components.create("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, Theme.pad.xs),
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				})

				local nameText = displayName .. (isMe and " (moi)" or "")
				Components.create("TextLabel", {
					Text = nameText .. "  —  " .. translateRole(role),
					Font = Theme.font.body,
					TextSize = Theme.text.sm,
					TextColor3 = Theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, Theme.text.sm + 6),
					LayoutOrder = 1,
					Parent = row,
				})

				-- Manager-only role buttons for other members
				if myRole == "Manager" and not isMe then
					local btnRow = Components.create("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 36),
						LayoutOrder = 2,
						Parent = row,
					}, {
						Components.listLayout({ horizontal = true, gap = Theme.pad.sm }),
					})

					local captureUserId = userId

					Components.Button({
						text = "→ Capitaine",
						variant = "secondary",
						TextSize = Theme.text.sm,
						Size = UDim2.fromOffset(110, 32),
						LayoutOrder = 1,
						Parent = btnRow,
						onClick = function()
							local Team = Knit.GetService("TeamService")
							Team:AssignRole(captureUserId, "Captain")
								:andThen(function(ok)
									if ok then
										Dock:Toast("Rôle mis à jour.", Theme.color.success)
									else
										Dock:Toast("Échec.", Theme.color.danger)
									end
								end)
								:catch(function()
									Dock:Toast("Échec.", Theme.color.danger)
								end)
						end,
					})

					Components.Button({
						text = "→ Joueur",
						variant = "ghost",
						TextSize = Theme.text.sm,
						Size = UDim2.fromOffset(88, 32),
						LayoutOrder = 2,
						Parent = btnRow,
						onClick = function()
							local Team = Knit.GetService("TeamService")
							Team:AssignRole(captureUserId, "Player")
								:andThen(function(ok)
									if ok then
										Dock:Toast("Rôle mis à jour.", Theme.color.success)
									else
										Dock:Toast("Échec.", Theme.color.danger)
									end
								end)
								:catch(function()
									Dock:Toast("Échec.", Theme.color.danger)
								end)
						end,
					})
				end
			end

			-- Leave button
			Components.Button({
				text = "Quitter l'équipe",
				variant = "danger",
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 5,
				Parent = container,
				onClick = function()
					local Team = Knit.GetService("TeamService")
					Team:Leave()
						:andThen(function(ok)
							if ok then
								Dock:Toast("Équipe quittée.", Theme.color.success)
							else
								Dock:Toast("Impossible de quitter.", Theme.color.danger)
							end
						end)
						:catch(function()
							Dock:Toast("Impossible de quitter.", Theme.color.danger)
						end)
				end,
			})
		end
	end

	Dock:Register({
		id = "team",
		label = "Équipe",
		order = 40,
		build = function(content)
			-- Vertical scrollable container that fills the content frame
			container = Components.create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = content,
			}, {
				Components.listLayout({ gap = Theme.pad.sm }),
				Components.padding(Theme.pad.sm),
			})

			local Team = Knit.GetService("TeamService")
			Team.TeamUpdated:Connect(function(updatedTeam)
				render(updatedTeam)
			end)
			Team:GetMyTeam()
				:andThen(function(myTeam)
					render(myTeam)
				end)
				:catch(function()
					render(nil)
				end)
		end,
		onOpen = function()
			local Team = Knit.GetService("TeamService")
			Team:GetMyTeam()
				:andThen(function(myTeam)
					render(myTeam)
				end)
				:catch(function()
					render(nil)
				end)
		end,
	})
end

function TeamController:KnitStart() end

return TeamController
