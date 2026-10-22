# Street City Online — multi-role release-readiness audit

**Audit date:** 2026-10-22  
**Code target:** `main`  
**Status:** CONDITIONAL SOURCE HARDENING, **NOT a certified public release**  
**Environment:** connected GitHub source access; no running Roblox Studio, Luau compiler, published private test server, or live DataStore. No CI / GitHub Actions.

## Roles and evidence

| Role | Observed defect/risk | Correction and verification |
|---|---|---|
| New player (mobile & desktop) | Car-delivery work demanded staying seated exactly on a stop: players stepping out after parking could fail permanently | `CareerRules.CanDeliverAfterParking` permits finishing for 20 seconds after a confirmed owned-car approach within 25 studs, on foot within 16 studs and within 12 studs elevation; Studio assertions include success, timeout, car far away, unsupported height and no car |
| Anti-cheat reviewer | A fixed 55-stud movement allowance every ~0.3 seconds also allowed repeated walking microteleports ~160 studs/sec to count as honest job travel | `CareerRules.MaximumMovementForSample` adds elapsed-time-dependent caps (28 studs/sec + 7 replicated-position tolerance on foot; 125 studs/sec + 12 in vehicles); applied to **both** old and new career services |
| Economy engineer | Old public-service shifts could count vehicle movement toward pedestrian-only tasks | `CityJobsService` records movement only in the correct mode; the taxi verifies ownership and actual driven distance, and completion occurs on foot after parking |
| Persistence engineer | With medical debt at 1,000,000 or 100,000,000 registered deaths, `LifeEconomy.DeathSettlement` returned failure without settling a later death | Debt and death count now saturate safely, preserving free clinic access; tests include maximal counters, zero-money treatment and repeated operation ID |
| QA automation | Existing smoke checks had no explicit parked-delivery or bounded movement cases | Expanded `LegalCareerTests`, `LifeEconomyTests` and static `tools/validate_project.py` gates |
| Delivery/product reviewer | 'Working source' and 'final ready build' could be conflated | `tools/release_gate.py` continues to require a real Rojo build and emits a block if unavailable. Roblox multiplayer and real DataStore verification remain required. |

## Executed in the audit environment

1. **16/16 PASS** — independent older Python model scenarios for DataStore leases, duplicate rewards, two-player isolation, garage purchases, parking and races. These do **not** execute Roblox Luau.
2. **15/15 PASS** — new Python model scenarios for speed caps, post-parking deliveries, distance/height rejection, free medical recovery at zero cash, protected home deposits, and saturated debt counters. These also do **not** execute Roblox Luau.
3. **24/24 PASS** — freshly fetched GitHub source consistency/invariant checks across nine service, client and test files, including startup wiring, exclusive work shift, server-only money settlement, medical counters and Studio test hookup. These are static checks, not runtime.
4. **UNRUN** — actual `rojo build`, Studio Luau diagnostics, 2–4 player interactive tests, Android driving, dynamic map collision, real DataStore errors or networking, performance profiling, published-game cash flow and any Robux product receipts.

## Mandatory certification steps before calling this a final product

1. From a local checkout: `python3 tools/release_gate.py` (fails closed when Rojo is missing); open the Rojo build in Roblox Studio.
2. Start a two-client Studio test and ensure all `Studio` suites PASS, including `LegalCareerTests` and `LifeEconomyTests`.
3. Exercise start → personal home → own car → driving profession → park → finish → credited wage → save → logout/rejoin. Repeat on mobile and with high latency.
4. Try walking microteleports and car teleports while working; neither may accrue mission distance. Try disconnecting during UpdateAsync, repeat prompt and respawn before completion; there must be no duplicate payout.
5. Verify death while broke, death at max medical debt, safe protected home balance, wanted stars, bounties and crew anti-collusion in a **private published staging place** with real Roblox services.
6. Run geometry/traffic/multiplayer load tests with world streaming and several active vehicles/NPCs; verify no void fall, collision spikes or player-property duplication.
7. Never enable paid Robux cash packages without `MarketplaceService.ProcessReceipt` idempotent purchase handling on a separate durable receipt record.

## Hard release limitations

- Some content is still explicitly prototype-level (procedural districts, placeholder car meshes, simplified NPC/traffic intelligence), regardless of the number of modules.
- The bounded 40-operation in-profile history is insufficient for developer-product/Robux receipt durability.
- Source-level patches and simulated domain rules alone cannot certify a 'completely finished' Roblox product.
- No force payment in Robux is required to revive; treatment debt preserves a free path back to play.

**Release decision: HOLD** until the real Roblox Studio and staging acceptance steps above pass.
