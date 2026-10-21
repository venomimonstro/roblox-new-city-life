# Deterministic simulation and source audit — 2026-10-21

## Scope and execution honesty

- **Executed here:** 16 offline Python model-based state-machine tests (16 passed, zero failures, zero errors). These tests independently mirror relevant gameplay rules and are not a Luau interpreter.
- **Added to project:** `src/server/dev/SimulationTests.luau`, a fake-UpdateAsync domain test using actual production Luau modules. Connected to unpublished/published Roblox Studio's server bootstrap alongside SmokeTests and ScenarioTests. These Luau tests have **not** been executed by the assistant because Roblox Studio/Rojo/Luau runtime is unavailable here.
- **Regression checks:** `tools/validate_project.py` guards the simulation hookup, production startup order, test-garage isolation and oriented player spawns. No CI/GitHub Actions installed.

## Scenarios modeled and passed offline

1. New profile acquisition and rejection of a second live server for the same account.
2. Expired lease takeover and denial of stale-server writes.
3. Insufficient credits rejects car purchase without debiting balance or recording a successful operation.
4. `UpdateAsync` callback replay does not award the same credits twice.
5. Duplicate reward ID rejected.
6. In-game part purchase deducts its price once, followed by installation/consumption and saved tuning.
7. Installation without remaining item rejected.
8. Safe lease release, rejoin and garage/balance persistence.
9. Renewing a lease does not overwrite newer saved credit data with stale in-memory values.
10. Two different player profiles are isolated.
11. The 40-entry operation history is bounded.
12. Eight-car garage capacity enforced.
13. All 48 parking positions are distinct, in their intended road rows and bounded.
14. Race waypoints follow orthogonal road segments and implausibly fast segments are rejected by the model.

16 independent Python test cases ran successfully; additional assertions occur inside individual cases.

## Confirmed defects changed in production Luau

- **Vehicle spawn alignment:** player cars used to face perpendicular to z=±200 parking roads, risking immediate departure from the street. `VehicleFactory.Create` now supports an explicit heading and `VehicleService.SpawnForPlayer` uses 90-degree yaw for east-west streets.
- **Developer garage persisted invalid schema:** shared prototype tuning replaced `profile.garage.starter` without required `catalogId`. The test stand now modifies ONLY the shared unpublished-Studio car, not player profiles or economy. Permanent tuning remains the separate personal garage shop.
- **Drifting simulation data:** the fake-store Luau suite now imports `RaceCourse` instead of repeating old course coordinates or reward amounts.
- **Test coverage:** a real Studio SmokeTests fixture asserts VehicleFactory produces an east-west-facing car. Offline simulation and Studio-only fake-UpdateAsync suite are present in the repository.

## Remaining P0/P1 acceptance gates

- Execute `python3 tools/validate_project.py` locally in a full checkout; execute `rojo build default.project.json -o StreetCity.rbxlx`. Source checks were inspected but not executed against a full local repository in this environment.
- Run the Studio server bootstrap test suites and inspect assertions/output. Test with 2–4 clients and a private published DataStore staging place.
- Delayed/ambiguous actual UpdateAsync writes; two different live servers racing for one account; crash/rejoin and shutdown.
- 48-car server physics load at 30Hz, suspended vehicles on varied terrain, mobile steering and slow-network synchronization.
- Complete mobile garage/shop UX and real wheels; currently prototype chassis and blockout world.
- Never enable public/Robux commerce solely on model-based test results.

**Release decision: HOLD.** These are real source changes plus a real execution of an offline model, not proof of a production-ready Roblox experience.
