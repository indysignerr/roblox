local TestKit = require("./TestKit")
local Team = require("../src/shared/Logic/Team")

local describe = TestKit.describe
local it = TestKit.it
local expect = TestKit.expect

-- Mirrors GameConfig.team so the tests are self-contained.
local CFG: Team.TeamCfg = {
	maxSize = 11,
	managers = 1,
	captains = 2,
	players = 8,
	leaveCooldownHours = 24,
}

-- Helper: build a team with the given members table.
local function makeTeam(members: { [number]: string }): Team.Team
	return { id = "t1", name = "Test FC", members = members }
end

describe("Team.roleCounts", function()
	it("counts an empty team as all zeros", function()
		local t = makeTeam({})
		local counts = Team.roleCounts(t)
		expect(counts.Manager).toBe(0)
		expect(counts.Captain).toBe(0)
		expect(counts.Player).toBe(0)
	end)

	it("counts a mixed roster correctly", function()
		local t = makeTeam({
			[1] = "Manager",
			[2] = "Captain",
			[3] = "Captain",
			[4] = "Player",
			[5] = "Player",
			[6] = "Player",
		})
		local counts = Team.roleCounts(t)
		expect(counts.Manager).toBe(1)
		expect(counts.Captain).toBe(2)
		expect(counts.Player).toBe(3)
	end)
end)

describe("Team.canJoin", function()
	it("allows joining when team is empty", function()
		local t = makeTeam({})
		expect(Team.canJoin(t, CFG)).toBeTruthy()
	end)

	it("blocks joining when team is at max capacity (11)", function()
		local members: { [number]: string } = {}
		for i = 1, 11 do
			members[i] = "Player"
		end
		local t = makeTeam(members)
		expect(Team.canJoin(t, CFG)).toBeFalsy()
	end)

	it("allows joining when one slot remains", function()
		local members: { [number]: string } = {}
		for i = 1, 10 do
			members[i] = "Player"
		end
		local t = makeTeam(members)
		expect(Team.canJoin(t, CFG)).toBeTruthy()
	end)
end)

describe("Team.canAssignRole", function()
	it("blocks a second Manager when one already exists (different user)", function()
		-- userId=1 is the existing Manager; try to assign Manager to userId=2.
		local t = makeTeam({ [1] = "Manager", [2] = "Player" })
		expect(Team.canAssignRole(t, 2, "Manager", CFG)).toBeFalsy()
	end)

	it("allows re-assigning the only Manager to Manager (same user, frees slot first)", function()
		local t = makeTeam({ [1] = "Manager" })
		expect(Team.canAssignRole(t, 1, "Manager", CFG)).toBeTruthy()
	end)

	it("allows a second Captain when only one exists", function()
		local t = makeTeam({ [1] = "Manager", [2] = "Captain", [3] = "Player" })
		-- Assigning Captain to userId=3 (currently Player, not a Captain yet).
		expect(Team.canAssignRole(t, 3, "Captain", CFG)).toBeTruthy()
	end)

	it("blocks a third Captain when two already exist", function()
		local t = makeTeam({
			[1] = "Manager",
			[2] = "Captain",
			[3] = "Captain",
			[4] = "Player",
		})
		-- userId=4 is Player; try to make them Captain (would be third Captain).
		expect(Team.canAssignRole(t, 4, "Captain", CFG)).toBeFalsy()
	end)

	it("allows reassigning a Captain to Captain (frees their own slot)", function()
		local t = makeTeam({
			[1] = "Manager",
			[2] = "Captain",
			[3] = "Captain",
		})
		-- userId=2 already Captain; re-assigning them should be fine (freeing their slot first).
		expect(Team.canAssignRole(t, 2, "Captain", CFG)).toBeTruthy()
	end)

	it("blocks a ninth Player when eight already exist", function()
		local members: { [number]: string } = { [1] = "Manager" }
		for i = 2, 9 do
			members[i] = "Player"
		end
		-- 8 Players already; try to add a ninth.
		local t = makeTeam(members)
		members[10] = "Captain" -- not a Player; shouldn't affect Player count
		expect(Team.canAssignRole(t, 10, "Player", CFG)).toBeFalsy()
	end)

	it("allows assigning Player when under the cap", function()
		local t = makeTeam({ [1] = "Manager", [2] = "Captain" })
		expect(Team.canAssignRole(t, 2, "Player", CFG)).toBeTruthy()
	end)
end)

describe("Team.canLeave", function()
	it("allows leaving when lastLeaveTime is nil (never left before)", function()
		expect(Team.canLeave(nil, 100000, 24)).toBeTruthy()
	end)

	it("blocks leaving within the 24-hour cooldown window", function()
		local now = 100000
		local lastLeave = now - (23 * 3600) -- 23 hours ago
		expect(Team.canLeave(lastLeave, now, 24)).toBeFalsy()
	end)

	it("allows leaving exactly at the cooldown boundary (24 h elapsed)", function()
		local now = 100000
		local lastLeave = now - (24 * 3600) -- exactly 24 hours ago
		expect(Team.canLeave(lastLeave, now, 24)).toBeTruthy()
	end)

	it("allows leaving after more than the cooldown has passed", function()
		local now = 200000
		local lastLeave = 100000 -- more than 24 h ago
		expect(Team.canLeave(lastLeave, now, 24)).toBeTruthy()
	end)
end)
