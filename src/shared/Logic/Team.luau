--!strict
-- PURE team logic. No requires, no Roblox globals -> Lune-testable.
-- Config is passed as arguments; the Team model is a plain table.

export type TeamCfg = {
	maxSize: number,
	managers: number,
	captains: number,
	players: number,
	leaveCooldownHours: number,
}

export type Team = {
	id: string,
	name: string,
	members: { [number]: string }, -- [userId] = role ("Manager"|"Captain"|"Player")
}

export type RoleCounts = {
	Manager: number,
	Captain: number,
	Player: number,
}

local Team = {}

-- Count members by role.
function Team.roleCounts(team: Team): RoleCounts
	local counts: RoleCounts = { Manager = 0, Captain = 0, Player = 0 }
	for _, role in team.members do
		if role == "Manager" then
			counts.Manager += 1
		elseif role == "Captain" then
			counts.Captain += 1
		else
			counts.Player += 1
		end
	end
	return counts
end

-- Total member count.
function Team.size(team: Team): number
	local n = 0
	for _ in team.members do
		n += 1
	end
	return n
end

-- True when the team has room for one more member.
function Team.canJoin(team: Team, cfg: TeamCfg): boolean
	return Team.size(team) < cfg.maxSize
end

-- True when assigning `role` to `targetUserId` would not exceed the cap for
-- that role. If the target already has a role it is freed first (a re-assignment
-- should not consume two slots of the same role).
function Team.canAssignRole(team: Team, targetUserId: number, role: string, cfg: TeamCfg): boolean
	local counts = Team.roleCounts(team)

	-- Free the target's current slot before checking the new slot.
	local currentRole = team.members[targetUserId]
	if currentRole == "Manager" then
		counts.Manager -= 1
	elseif currentRole == "Captain" then
		counts.Captain -= 1
	elseif currentRole == "Player" then
		counts.Player -= 1
	end

	if role == "Manager" then
		return counts.Manager < cfg.managers
	elseif role == "Captain" then
		return counts.Captain < cfg.captains
	elseif role == "Player" then
		return counts.Player < cfg.players
	end

	return false
end

-- True when a player is allowed to leave.
-- nil lastLeaveTime means they have never left -> always allowed.
-- Otherwise they must have waited at least cooldownHours * 3600 seconds.
function Team.canLeave(lastLeaveTime: number?, now: number, cooldownHours: number): boolean
	if lastLeaveTime == nil then
		return true
	end
	return (now - lastLeaveTime) >= cooldownHours * 3600
end

return Team
