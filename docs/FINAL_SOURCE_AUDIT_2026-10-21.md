# Finalization audit of current source — Street City Online

Date: 2026-10-21. All corrections committed to `main`. No GitHub Actions or CI.

## Decision

**Production release remains BLOCKED.** The source is more internally consistent, but there is no executable Roblox Studio session, published staging server, live DataStore verification, Rojo compiler, mobile profiling or real player experience in this environment. Claiming this project is a fully final commercial Roblox game would be inaccurate.

## Confirmed bugs fixed in this audit pass

| Area | Root cause | Implemented correction |
|---|---|---|
| Race start | Race relied on pressing interaction while seated and driving; touch players could miss it | Automatic entry-based server start, requires player's own car, re-arms after leaving zone |
| Stale account on join | `UpdateAsync` could reject a recent handoff while prior server still held a session lease | Bounded retry for acquiring persisted profile; invalid profiles fail closed |
| Garage spawn | A profile completing after the fixed 50-second polling window never spawned its car | Retry while the player is connected and profile becomes loaded |
| Missing car | Finder could not recover an owned car which fell through the world | Owner-only stationary/abandoned vehicle recovery to validated parking road; reset unsafe momentum |
| Unowned seat | A player could touch/force-seat into someone else's car briefly before the physics tick | Assign owner before parenting car into Workspace, eject invalid occupant immediately on seat change |
| Boot readiness | Partial server could be announced ready despite missing dealers/remotes/course | Production `StartupContract.Validate` checks world, garage, vehicles, race and remotes before ready message |
| Shop exceptions | One ProximityPrompt callback error was uncaught and user received no reliable state | Isolate callback errors and report uncertainty without implying unconfirmed rollback |
| Undeliverable car SKU | `sport_sedan` was present in catalog but lacked a purchase stand | Catalog-priced street coupe and sport sedan are both purchasable |
| Road blocking | District building centers were shifted 25 studs from road grid lines, causing about 2.5-stud overlaps | Repositioned district buildings at midpoint of each 100-stud block |
| Duplicate geometry | WorldService and DistrictService both generated downtown buildings in the same positions | DistrictService now owns district buildings; removed duplicate base-world batch |
| Development acceptance | Source-only string tests were treated as game readiness | Added one-command fail-closed local structural+Rojo build gate and expanded Studio smoke assertions |

## Tests actually executed

- **16/16 independent Python in-memory economy/state-machine tests PASS**, including duplicate transactions, two competing server tokens, replayed updates, credits, purchases, garage and rejoin. This is a model of source rules, not execution of production Luau.
- **55/55 district building positions tested against street clearances** from current `DistrictConfig` and `DistrictService` source: 7 districts, 0 street overlaps, 22.5 studs nearest clearance on nominal 25-stud roads.
- GitHub main source audits inspected startup sequencing, owner assignment order, timeout guards, automatic racing, shop item transactions and garage recovery.
- In-Studio `SmokeTests`, `ScenarioTests`, `SimulationTests` are authored and connected to server bootstrap. They have **not been run by this assistant**.

## One-command local build gate

```sh
python3 tools/release_gate.py
```

This runs the static project checks and actual `rojo build`. If Rojo is absent or the build fails, it returns a nonzero status and refuses to claim readiness. It does **not** install packages or publish to Roblox. This command has not been run against the full GitHub checkout from the assistant runtime due to unavailable repo network and build tools.

## Outstanding release blockers — do not mask as completed sprints

- Real Roblox Studio Luau compilation/diagnostics and automated Studio scenario execution.
- First-session 2–4 actual players with mobile control, gamepad, seat transitions, character respawn, ownership and chatless onboarding.
- Private published staging DataStore: real account migration, lease contention, outage, timeout-after-commit, crash and server shutdown.
- Server-side physics stability on slopes, collisions, 30Hz force calculation and network latency; realistic independent suspension and actual distinct car assets absent.
- Seven city districts remain blockouts and placeholders. NPC traffic and multiplayer PvP race modes are unimplemented.
- Mobile UX and accessibility, streaming/LOD/load profiling, operational telemetry and moderation are not production-grade.
- In-game-credit operations have a bounded recent-ID journal. This **must not be used as Robux purchase receipt processing**.

**This audit does not assert that absolutely all project bugs have been eliminated.** It closes specific reproducible source defects while preserving an explicit production-release gate.
