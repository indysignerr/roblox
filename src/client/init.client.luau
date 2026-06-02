--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllersDeep(script.Controllers)

Knit.Start()
	:andThen(function()
		print("[WorldCupBrainrot] Knit client started")
	end)
	:catch(function(err)
		warn("[WorldCupBrainrot] Knit client failed: " .. tostring(err))
	end)
