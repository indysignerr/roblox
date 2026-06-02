--!strict
-- Minimal Lune test harness (describe / it / expect). No external deps.
-- Specs require this with `require("./TestKit")`. The runner calls TestKit.report().

local TestKit = {}

type Failure = { name: string, err: string }
local results = { passed = 0, failed = 0, failures = {} :: { Failure } }
local stack: { string } = {}

local function fullName(name: string): string
	if #stack == 0 then
		return name
	end
	return table.concat(stack, " > ") .. " > " .. name
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function repr(v: any): string
	return if type(v) == "table" then "<table>" else tostring(v)
end

function TestKit.describe(name: string, fn: () -> ())
	table.insert(stack, name)
	local ok, err = pcall(fn)
	table.remove(stack)
	if not ok then
		results.failed += 1
		table.insert(results.failures, { name = name .. " (describe threw)", err = tostring(err) })
	end
end

function TestKit.it(name: string, fn: () -> ())
	local label = fullName(name)
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
		print("  [PASS] " .. label)
	else
		results.failed += 1
		table.insert(results.failures, { name = label, err = tostring(err) })
		print("  [FAIL] " .. label)
	end
end

function TestKit.expect(value: any)
	return {
		toBe = function(expected: any)
			if value ~= expected then
				error("expected (identity) " .. repr(expected) .. " but got " .. repr(value), 2)
			end
		end,
		toEqual = function(expected: any)
			if not deepEqual(value, expected) then
				error("expected " .. repr(expected) .. " but got " .. repr(value), 2)
			end
		end,
		toBeTruthy = function()
			if not value then
				error("expected a truthy value but got " .. repr(value), 2)
			end
		end,
		toBeFalsy = function()
			if value then
				error("expected a falsy value but got " .. repr(value), 2)
			end
		end,
		toBeCloseTo = function(expected: number, tolerance: number?)
			local tol = tolerance or 1e-6
			if type(value) ~= "number" or math.abs(value - expected) > tol then
				error("expected ~" .. tostring(expected) .. " but got " .. repr(value), 2)
			end
		end,
	}
end

function TestKit.report(): boolean
	print("")
	print(string.format("Tests: %d passed, %d failed", results.passed, results.failed))
	if results.failed > 0 then
		print("Failures:")
		for _, f in results.failures do
			print("  - " .. f.name)
			print("      " .. f.err)
		end
		return false
	end
	return true
end

return TestKit
