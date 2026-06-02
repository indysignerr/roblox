# AGENTS.md — World Cup Brainrot (build brief for parallel agents)

You are building **one system** of a viral-style Roblox football card game
(collect / steal / fuse / battle), Luau + Rojo + Knit. Other agents build the
other systems **in parallel**, in isolated git worktrees. Read this whole file
before writing code. When you finish, your work MUST pass `./scripts/validate.sh`.

---

## 0. The golden rules (break these and the merge fails)

1. **Only ADD files in the directories you are told to own.** Never edit another
   system's files. Never edit these shared/locked files:
   `default.project.json`, `wally.toml`, `rokit.toml`, `stylua.toml`,
   `selene.toml`, `.luaurc`, `scripts/*`, `src/shared/Types.luau`,
   `src/shared/Config/GameConfig.luau`, `src/shared/Config/Rarities.luau`,
   `vendor/*`, `src/server/init.server.luau`, `src/client/init.client.luau`.
   (You MAY read all of them.)
2. **No new Wally packages.** If you think you need one, stop and write the need
   into your final report instead — do not edit `wally.toml`.
3. **The validation gate is law.** `./scripts/validate.sh` must exit 0 before you
   declare done. It runs StyLua, selene, a Rojo sourcemap, luau-lsp type-check,
   and the Lune test suite. No exceptions, no skipping.
4. **IDENTITY RULE (legal / moderation):** a card's `nation` is a real country
   (allowed). A card's `name` is ALWAYS an **original parody / brainrot
   character** — NEVER a real player's name or likeness. Same for any visual,
   emote, or trash-talk content: original only, never a real person.
5. **Never invent secrets, never commit secrets.** No API keys in code.

---

## 1. Architecture (why it's testable without Studio)

```
src/shared/Logic/*.luau    PURE logic. No Roblox globals, NO requires.
                           Config is passed in as arguments. -> Lune-testable.
src/shared/Config/*.luau   PURE data. No requires. -> loads under Lune.
src/shared/Types.luau      Canonical types. (LOCKED — read only.)
src/server/Services/*.luau Knit Services. Wire pure logic to the Roblox runtime
                           and to DataService. Type-checked + playtested.
src/client/Controllers/*   Knit Controllers (client). UI + calls to services.
tests/*.spec.luau          Lune tests. Auto-discovered by the runner.
```

**The split is the whole point.** Put every decision/calculation in a pure
`Logic` module that takes plain tables/numbers and returns plain results. Unit
test THAT under Lune (fast, no Studio). The Service is then a thin shell:
read profile → call logic → write profile → fire signals/remotes. Keep Services
small; keep logic pure.

A pure logic module looks like this (NO `require`, NO `game`):

```lua
--!strict
local Fusion = {}
function Fusion.resolve(rarityCounts: { [string]: number }, roll: number): boolean
	-- ...pure...
end
return Fusion
```

A config module is just data:

```lua
--!strict
return { foo = 1, bar = { "a", "b" } }
```

---

## 2. Knit — how your Service plugs in (zero central registry)

The server bootstrap does `Knit.AddServicesDeep(script.Services)` and the client
does `Knit.AddControllersDeep(script.Controllers)`. **Just drop your
`<Name>Service.luau` into `src/server/Services/` and it is auto-registered.** No
file to edit, no list to append — this is what makes parallel work safe.

Server service skeleton:

```lua
--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local FooService = Knit.CreateService({
	Name = "FooService",
	Client = {}, -- methods/​signals exposed to the client go here
})

function FooService:KnitInit()
	-- runs once, all services constructed; grab deps with Knit.GetService("X")
end

function FooService:KnitStart()
	-- runs after every service's KnitInit
end

return FooService
```

- Call a sibling service: `local Data = Knit.GetService("DataService")` (do it
  inside `KnitInit`/`KnitStart` or later, never at module top level).
- Expose to client: put a method on `.Client`, e.g.
  `function FooService.Client:Buy(player, id) ... end`. Knit makes the
  RemoteFunction automatically. Use `self.Server` inside a client method to reach
  the server-side service.
- Client→server signals: declare `FooService.Client.SomethingHappened =
  Knit.CreateSignal()` and `:Fire(player, ...)`.

Controller skeleton (client):

```lua
--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local FooController = Knit.CreateController({ Name = "FooController" })

function FooController:KnitStart()
	local FooService = Knit.GetService("FooService") -- the .Client surface
end

return FooController
```

---

## 3. The DataService contract (STABLE — build against this)

Every player's saved state lives in one `ProfileData` table (see
`src/shared/Types.luau`). You read and **mutate it in place** through
`DataService` (backed by session-locked ProfileStore; mutations autosave).

```lua
local Data = Knit.GetService("DataService")

local profile = Data:GetProfile(player)   -- ProfileData? (nil if not loaded yet)
if profile then
	profile.coins += 50                    -- direct mutation persists
	profile.stats.steals += 1
end

Data:GetCoins(player)                       -- number
Data:AddCoins(player, -250)                 -- boolean: false if it would go < 0

Data.ProfileLoaded:Connect(function(player, data) end)    -- on load
Data.ProfileReleasing:Connect(function(player, data) end)  -- before save/leave
```

`ProfileData` shape (do not redefine it; extend only by adding keys to the
template if your system needs new persistent state — but that means editing the
LOCKED DataService, so instead: **ask in your report** if you need a new
persistent field, and for now store transient state in your own service table):

```
coins, cards: { [cardId] = { cardId, count, aura } }, shield { active, expiresAt },
streak { current, lastClaimDay }, teamId?, unlockedZones { [zone]=bool },
lastDailyPackDay, stats { steals, stolenFrom, fusions, wins }, createdAt
```

If two systems must talk, prefer going through the profile. Direct service calls
are fine via `Knit.GetService` when a real dependency exists (e.g. Steal must
check Shield). Reference sibling service method names from the contracts in
your task prompt; type them loosely (`:: any`) to avoid coupling the type-check.

### InventoryService contract (STABLE — use it; do NOT reimplement card mutation)

All card grants/consumes go through this so anti-dupe + replication stay in one
place. Grab it with `local Inv = Knit.GetService("InventoryService")`:

```lua
Inv:GrantCard(player, cardId)            -- boolean: add one copy (stacks)
Inv:ConsumeCards(player, cardId, n)      -- boolean: false if not enough copies
Inv:HasCard(player, cardId, n?)          -- boolean
Inv:GetCard(player, cardId)              -- OwnedCard? { cardId, count, aura }
Inv:ConvertDuplicates(player, cardId, keep?) -- number coins (anti-dupe: surplus -> coins)
```

The pure math behind it is `src/shared/Logic/Inventory.luau`
(`grant`/`consume`/`has`/`convertDuplicates`) — reuse that in your own pure logic
+ tests when you need to reason about a cards map.

### Catalog (pure) — look up CardDefs

`src/shared/Logic/Catalog.luau` operates on the card list (`Config.Cards`):
`Catalog.get(cards, id)`, `.byRarity(cards, r)`, `.byNation(cards, n)`,
`.index(cards)`, `.nations(cards)`. Require `Cards` + `Catalog` and call directly
(both are pure / present in the base).

---

## 4. Config you can rely on (read-only)

- `src/shared/Config/GameConfig.luau` — all tunables (shield 600s/500c, fusion
  5 Rare→Epic @0.80, team 11 = 1+2+8, packs, nationScore weights, spyRobuxCost…).
- `src/shared/Config/Rarities.luau` — `order`, `weights`, `dupeValue`,
  `marketTax` (progressive 0.05→0.25), `auraMaxLevel = 5`.
- `src/shared/Config/Cards.luau` — the card catalogue (CardDef list).
- `src/shared/Logic/RarityRoll.luau` — `RarityRoll.pick(weights, order, roll)`
  weighted picker (already tested; reuse it for any random pull).

Need a new tunable? Put it in YOUR OWN config file under `src/shared/Config/`
(e.g. `MinigameConfig.luau`) — don't touch the locked ones.

---

## 5. Tests (required — at least cover your pure logic)

Add `tests/<YourSystem>.spec.luau`. The runner auto-discovers `*.spec.luau`.
Pattern:

```lua
local TestKit = require("./TestKit")
local MyLogic = require("../src/shared/Logic/MyLogic")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("MyLogic.something", function()
	it("does the thing", function()
		expect(MyLogic.something(1, 2)).toBe(3)
	end)
end)
```

`expect` supports `.toBe`, `.toEqual` (deep), `.toBeTruthy`, `.toBeFalsy`,
`.toBeCloseTo`. Run just the tests with `lune run scripts/run-tests`, or the full
gate with `./scripts/validate.sh`.

---

## 6. Style / lint (StyLua + selene)

- Tabs for indentation, 100 col, double quotes, always call with parens
  (StyLua enforces on `--check`; run `stylua src tests scripts` to auto-format).
- selene `std = roblox`; no unused variables, no shadowing.
- Prefer `--!strict` in pure Logic/Config and shared modules. Services that lean
  on Knit's dynamic `self` may use `--!nonstrict` (like DataService) — but keep
  pure logic strict and tested.

---

## 7. Definition of done

1. Your system's pure logic lives in `src/shared/Logic/`, with tests.
2. Your Service lives in `src/server/Services/<Name>Service.luau` and exposes the
   methods named in your task contract (server + `.Client` as specified).
3. Any new tunables are in your own `src/shared/Config/*` file.
4. `./scripts/validate.sh` exits 0 (StyLua, selene, type-check, tests all green).
5. Your final report lists: files added, the public API you exposed, anything you
   needed but couldn't do without editing a LOCKED file (so it can be merged in).
