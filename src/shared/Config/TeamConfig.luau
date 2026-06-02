--!strict
-- Team Manager tunables. Pure data (no requires) -> Lune-testable.
-- Most defaults come from GameConfig.team; this file holds any
-- Team-Manager-specific extras that don't belong in GameConfig.

local TeamConfig = {
	-- Fallback displayed when a team name is not provided.
	defaultTeamName = "New Team",

	-- Maximum length of a team name in characters.
	maxNameLength = 32,
}

return TeamConfig
