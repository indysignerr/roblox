--!strict
-- Zone unlock definitions. Pure data (no requires) -> Lune-testable.
-- Each entry: name (display label) + cost (coins required to unlock).

local ZoneConfig = {
	stadium = {
		name = "Stade",
		cost = 500,
	},
	vip = {
		name = "Tribune VIP",
		cost = 5000,
	},
	legends = {
		name = "Allée des Légendes",
		cost = 50000,
	},
}

return ZoneConfig
