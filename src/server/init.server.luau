--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Auto-discovery: every ModuleScript under Services/ that returns a Knit service
-- is registered. Agents just drop their *Service.luau here -- no central registry to edit.
Knit.AddServicesDeep(script.Services)

Knit.Start()
	:andThen(function()
		print("[WorldCupBrainrot] Knit server started")
	end)
	:catch(function(err)
		warn("[WorldCupBrainrot] Knit server failed: " .. tostring(err))
	end)
