--!nonstrict
-- TeamService: manages team creation, joining, leaving, and role assignment.
-- Pure decisions are delegated to src/shared/Logic/Team.luau.
-- Persistence note: _teams (rosters) are in-memory only; the per-player leave
-- cooldown persists on profile.lastTeamLeaveAt. Cross-server rosters are a v2 need.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TeamLogic = require(ReplicatedStorage.Shared.Logic.Team)

local TeamService = Knit.CreateService({
	Name = "TeamService",
	Client = {
		-- Fired to every member when team state changes.
		TeamUpdated = Knit.CreateSignal(), -- (team snapshot)
	},

	-- In-memory roster: { [teamId] = Team }
	-- NOT persisted across server restarts; see report for persistence needs.
	_teams = {},
})

local _Data = nil :: any -- DataService, fetched in KnitInit

-- ────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ────────────────────────────────────────────────────────────────────────────

-- Fire TeamUpdated to every current member of a team.
function TeamService:_fireUpdated(teamId: string)
	local team = self._teams[teamId]
	if not team then
		return
	end
	-- Build a snapshot (shallow copy is enough for clients).
	local snapshot = {
		id = team.id,
		name = team.name,
		members = {},
	}
	for uid, role in team.members do
		snapshot.members[uid] = role
	end
	for userId in team.members do
		-- Fire to whoever is in-game; Players lookup is best-effort.
		local ok, players = pcall(function()
			return game:GetService("Players"):GetPlayers()
		end)
		if ok then
			for _, player in players do
				if player.UserId == userId then
					self.Client.TeamUpdated:Fire(player, snapshot)
					break
				end
			end
		end
	end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Client-facing methods
-- ────────────────────────────────────────────────────────────────────────────

-- Create a new team. The calling player becomes the sole Manager.
-- Returns the new teamId on success, nil on failure.
function TeamService.Client:Create(player: Player, name: string): string?
	local profile = _Data:GetProfile(player)
	if not profile then
		return nil
	end
	if profile.teamId ~= nil then
		-- Already in a team.
		return nil
	end

	local teamId: string = HttpService:GenerateGUID(false)
	local team: TeamLogic.Team = {
		id = teamId,
		name = name,
		members = { [player.UserId] = "Manager" },
	}

	self.Server._teams[teamId] = team
	profile.teamId = teamId
	_Data:FireUpdated(player)
	self.Server:_fireUpdated(teamId)

	return teamId
end

-- Join an existing team as a Player.
-- Returns true on success.
function TeamService.Client:Join(player: Player, teamId: string): boolean
	local profile = _Data:GetProfile(player)
	if not profile then
		return false
	end
	if profile.teamId ~= nil then
		return false
	end

	local team = self.Server._teams[teamId]
	if not team then
		return false
	end
	if not TeamLogic.canJoin(team, GameConfig.team) then
		return false
	end

	team.members[player.UserId] = "Player"
	profile.teamId = teamId
	_Data:FireUpdated(player)
	self.Server:_fireUpdated(teamId)

	return true
end

-- Leave the player's current team.
-- Returns true on success.
function TeamService.Client:Leave(player: Player): boolean
	local profile = _Data:GetProfile(player)
	if not profile then
		return false
	end

	local teamId = profile.teamId
	if teamId == nil then
		return false
	end

	-- Cooldown timestamp persists on the profile, so it survives rejoin/restart.
	local lastLeave: number? = profile.lastTeamLeaveAt
	if not TeamLogic.canLeave(lastLeave, os.time(), GameConfig.team.leaveCooldownHours) then
		return false
	end

	local team = self.Server._teams[teamId]
	if team then
		team.members[player.UserId] = nil

		-- Delete the team entirely if now empty.
		if TeamLogic.size(team) == 0 then
			self.Server._teams[teamId] = nil
		else
			self.Server:_fireUpdated(teamId)
		end
	end

	profile.teamId = nil
	profile.lastTeamLeaveAt = os.time()
	_Data:FireUpdated(player)

	return true
end

-- Assign a role to another team member.
-- Only the Manager of the team may call this.
-- Returns true on success.
function TeamService.Client:AssignRole(player: Player, targetUserId: number, role: string): boolean
	local profile = _Data:GetProfile(player)
	if not profile then
		return false
	end

	local teamId = profile.teamId
	if teamId == nil then
		return false
	end

	local team = self.Server._teams[teamId]
	if not team then
		return false
	end

	-- Caller must be the Manager.
	if team.members[player.UserId] ~= "Manager" then
		return false
	end

	-- Target must already be in this team.
	if team.members[targetUserId] == nil then
		return false
	end

	if not TeamLogic.canAssignRole(team, targetUserId, role, GameConfig.team) then
		return false
	end

	team.members[targetUserId] = role
	self.Server:_fireUpdated(teamId)

	return true
end

-- Return a snapshot of the player's current team, or nil.
function TeamService.Client:GetMyTeam(player: Player): TeamLogic.Team?
	local profile = _Data:GetProfile(player)
	if not profile then
		return nil
	end

	local teamId = profile.teamId
	if teamId == nil then
		return nil
	end

	local team = self.Server._teams[teamId]
	if not team then
		return nil
	end

	-- Return a shallow snapshot to avoid direct mutation from client code.
	local snapshot: TeamLogic.Team = {
		id = team.id,
		name = team.name,
		members = {},
	}
	for uid, role in team.members do
		snapshot.members[uid] = role
	end
	return snapshot
end

-- ────────────────────────────────────────────────────────────────────────────
-- Knit lifecycle
-- ────────────────────────────────────────────────────────────────────────────

function TeamService:KnitInit()
	_Data = Knit.GetService("DataService")
end

function TeamService:KnitStart() end

return TeamService
