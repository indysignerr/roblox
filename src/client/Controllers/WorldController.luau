--!nonstrict
-- WorldController: bridges the physical world (kiosks/bornes built by WorldService) to the
-- UI. Each kiosk Base part carries a `WCBPanel` attribute; triggering its ProximityPrompt
-- opens the matching dock panel. Runs per client, so PromptTriggered fires for the local
-- player's interactions.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local WorldController = Knit.CreateController({
	Name = "WorldController",
})

function WorldController:KnitStart()
	local Dock = Knit.GetController("DockController")

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer then
			return
		end
		local holder = prompt.Parent
		local panelId = holder and holder:GetAttribute("WCBPanel")
		if panelId then
			Dock:Open(panelId)
		end
	end)
end

function WorldController:KnitInit() end

return WorldController
