# Street City Online — commercial release audit and acceptance plan
Date: 2026-10-24. Repository: `venomimonstro/roblox-new-city-life`, `main`.
Release decision: **BLOCKED** until executed evidence exists, not merely authored tests.

## Verified source architecture

- Server bootstrap starts and orders approximately 40 world, account, transport, NPC, career, law, economy and housing services, then runs `WorldSurfaceAudit.Validate` and `StartupContract.Validate`.
- LuaU `IntegratedTestRunner` lists **16 Studio-only suites**, produces one structured JSON receipt and fails a boot where any suite errors.
- `PlayerJourneyProbe` observes genuine connected avatars, homes, active owned cars, basic GUI remotes and the collision floor; it is **not** a driving test.
- Existing Python `tools/validate_project.py` performs structural and source-regression checks; `tools/release_gate.py` builds a Rojo place if the tool is available.
- Added `AutomatedMultiplayerAcceptance.luau`: **two genuine Studio test clients** must be loaded and have distinct residences, owned vehicles, actual UI and healthy avatars; then actual avatar death + free home respawn must increment medical/death state without mutating the other account.
- Added `AutomatedClientAcceptance.client.luau` for each real Studio client to verify the rendered HUD, career navigation, bounty board and minimap objects exist.
- Added `tools/run_full_acceptance.py` and `tools/studio/launch_release_acceptance.luau`: one command builds, launches Studio's documented multi-client scripted testing and rejects absent or failed 16/16 suites or any of nine mandatory two-player checks.
- Confirmed and fixed Studio test players with negative UserIds being rejected by `HomeLayout.Preferred`. Added Luau assertion for -1 and -2.

**Execution honesty:** Source files and GitHub commits were examined and changed. This environment lacks local Rojo, Luau and Roblox Studio. Thus **0 of 16 Studio suites** and **0 of 9 live multiplayer acceptance checks** have been observed executing here. They must not be reported as passed.

## Sprint by sprint

| Sprint | Product scope | Current source status | Launch status |
|---|---|---|---|
| 00 | Rojo modules, boot, doc and tests | Present, heavily extended | BLOCKED: actual build |
| 01 | Home spawn, real avatar, 2 clients | Present; automated 2-client acceptance authored | BLOCKED: execute Studio |
| 02 | Driver inputs, lighting, seats | Present | BLOCKED: real controls |
| 03 | Engine, vehicle dynamics, suspension | Partial; physics prototype | BLOCKED: real vehicle benchmark |
| 04–05 | Connected city, 7 districts, surfaces | Procedural sources and collision audit present | BLOCKED: continuous traversal, streaming |
| 06 | Asset toolchain and production cars | Placeholder vehicles and scenery remain | BLOCKED: art + rig quality |
| 07–08 | Personal garage, purchase, tuning | Server code and profile persistence present | BLOCKED: published DataStore integration |
| 09 | Ambient traffic, citizens and police cars | Prototype bounded NPC source present | BLOCKED: spawn/AI/path stability |
| 10 | Racing and payouts | Solo time trial exists | BLOCKED: real driving/race anti-cheat |
| 11 | In-game credit economy | Present, idempotent rule modules | BLOCKED: staging and replay |
| 12 | UX/Android/controls | Client HUD, minimap, navigation and prompts present | BLOCKED: screen/device tests |
| 13 | Security, profile lease/migration | Multiple defensive implementations and tests | BLOCKED: two-server failures |
| 14 | Streaming/performance | Partial optimization work | BLOCKED: measured device/server budget |
| 15 | Published public beta and launch | No proven live game acceptance | BLOCKED |
| 16 | Car impact/damage/rescue | Damage modules and Studio tests authored | BLOCKED: real collision/physics |
| 17 | Dispatch, police, jail | Wanted/patrol/bounty prototypes; full arrest process unproven | BLOCKED |
| 18 | Combat and equipment | Stylized armory and server hit checks | BLOCKED: PvP fairness, abuse, moderation |
| 19 | Housing economy, social, guilds, districts | Significant source prototypes; district and property rights session-scoped | BLOCKED: cross-server state |
| 20 | 21+ legal jobs, fishing and wildlife | Server job logic and many mission tests authored | BLOCKED: end-to-end play |
| 21 | Robux -> credits | No verified durable `MarketplaceService.ProcessReceipt` purchase flow | BLOCKED; keep OFF |

A module being present is not a finished user-visible mechanic. In particular the GTA-like police AI, realistic distinct cars, global neighborhood control and real player property exchange must not be sold as complete.

## Whole-game release conditions (ordered)

### Gate A — 100% source/build automated
1. No missing mapped source files or broken startup dependencies, clean Luau diagnostics.
2. Actual Rojo build produces an openable .rbxlx file.
3. All 16 Studio suites execute, **16 pass / 0 fail**. Not merely tests that exist in the repository.

### Gate B — automated multiplayer player lifecycle
4. Two actual players enter one server, load profiles, receive unique homes/owned vehicles.
5. Each sees HUD, map, jobs and wanted board in separate clients.
6. Real Humanoid death triggers one hospital payment/debt entry, one free home respawn, repaired owned car, and zero mutations to the other player.
7. Automated tester gets JSON receipt from `StudioTestService:EndTest` and machine-verifies all checks. Timeout, no marker or missing Studio tool must result in BLOCKED.

### Gate C — automatic staging integration (must still be developed)
8. Dedicated private published experience; no production wallet or account used.
9. Two-server lease contention, UpdateAsync timeout *after write*, profile migration and rollback.
10. Purchases, salaries, rent, bank-to-wallet, home-safe transfers, bounty rewards and death settlement: idempotent across retries and reconnects.
11. Abuse every RemoteEvent with NaN, infinities, huge amounts, unowned cars, fake victims and rapid remote calls; no credit creation.
12. Server-authoritative mission tracking across lag and client disconnects.

### Gate D — automatic physics, mobile, stress (must still be developed)
13. Bot-driven walk/drive across all seven districts; fail on falling through terrain, unsafe ground, blocked or unloaded map.
14. Vehicle destruction, crashes, stealing, police, GPS, race and owned garage recovery with 2, 4 and 8 test clients.
15. StudioDeviceSimulatorService / VirtualInput UI automation for portrait/landscape and touch.
16. Streaming-enabled client profiling and sustained memory/fps under target mobile/server hardware. Record measured p95, not guessed averages.
17. Test Roblox purchases only after `ProcessReceipt` with durable PurchaseId journal, safe fail/replay and offline receipt recovery is implemented.

### Gate E — short owner acceptance, not weeks of exploratory QA
After A–D are green: 20–30 minutes of subjective playability review for driving enjoyment, readable mobile interface, NPC credibility and economy pacing. Only this final judgment requires direct human taste; crucial correctness and abuse cases must be automated.

## Measurable automation target

The request **99% of testing automated** is a release design goal, **not a currently attained score**. Define a versioned scenario inventory and use this formula:

`automation coverage = executed automated acceptance cases / all executable acceptance cases`.

Every case requires a named test, actual run timestamp, game/build commit, environment, result and diagnostic. Exclude unexecuted files from the numerator. Missing or failed P0 cases block launch regardless of the percentage. Full coverage by count is not the same as 99% absence of bugs or guaranteed player experience.

## Launch command (on a machine with Roblox Studio + Rojo)

```sh
python3 tools/run_full_acceptance.py
```

This performs static validation, builds a temporary Rojo place, launches the 2-player scripted Studio acceptance and records `street-city-acceptance.json` and `street-city-acceptance.log`. It returns an error if Roblox Studio/Rojo is not installed, the build is invalid, the test hangs, or any mandatory result is absent. No CI or GitHub Actions.

Roblox Studio's official testing interface exposes `StudioTestService:ExecuteMultiplayerTestAsync` for genuine multiplayer simulation; Studio also supports scripted tests through the `--task RunScript` CLI. The tool is a new integration path and is **not** proven until run on the developer workstation.

## Product decision

**Do not launch paid Robux credits, player property sales, bounties for real players or global district politics until the corresponding datastore, authorization, abuse and recovery gates are actually verified.**

Current verdict: **source-rich game prototype; automated multi-client acceptance instrumented but unexecuted; full commercial launch blocked**.
