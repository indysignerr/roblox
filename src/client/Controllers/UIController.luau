--!nonstrict
-- Starting point for the client UI layer. The UI agent expands this (or adds sibling
-- controllers). Kept minimal so the Controllers folder exists and Knit boots cleanly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local UIController = Knit.CreateController({
	Name = "UIController",
})

function UIController:KnitInit() end

function UIController:KnitStart() end

return UIController
