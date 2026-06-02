--!strict
-- Lune test runner: discovers tests/*.spec.luau, requires each (which registers its
-- cases via TestKit), then reports and sets the exit code.

local fs = require("@lune/fs")
local process = require("@lune/process")

local TestKit = require("../tests/TestKit")

local TESTS_DIR = "tests"

local specs: { string } = {}
for _, entry in fs.readDir(TESTS_DIR) do
	if string.match(entry, "%.spec%.luau$") then
		table.insert(specs, (string.gsub(entry, "%.luau$", "")))
	end
end
table.sort(specs)

for _, moduleName in specs do
	require("../tests/" .. moduleName)
end

local ok = TestKit.report()
process.exit(if ok then 0 else 1)
