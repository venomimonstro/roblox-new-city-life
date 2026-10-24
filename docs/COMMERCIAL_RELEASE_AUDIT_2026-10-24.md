# Street City Online — commercial release audit / system acceptance
Date: 2026-10-24. Audited main HEAD: 20b8068d4aa5d7ba7f169f9ab158d9d23cd9ff13.
Status: **HOLD (not release-certified)**.

## What actually exists (source evidence)
- Bootstrap starts ~40 game services inside a single guarded initialization flow, including profile/data store, seven districts, 48 homes, owned vehicles, street traffic, jobs, housing/property, banking, gangs/territory, wanted/bounties, weather, NPCs, recreation, public transit and minigames.
- StartupContract checks critical world instances, terminals, remotes, NPC vehicles, home interiors, jobs, clinic and bounty terminal.
- WorldSurfaceAudit performs Roblox-engine raycasts across the actual generated street grid and home positions; these are **Studio/engine runtime checks, not offline geometry certification**.
- 16 legal multi-leg careers plus five older public service missions, and fishing exist in source. The two work systems share a WorkShiftRegistry.
- Shared profile schema V4 validates selected cars, garages, money accounts, property, skills and safety investments. ProfileService uses UpdateAsync with ownership leases, but live failure behavior has not been certified.
- Many Studio test modules exist: SmokeTests, CityTraversalTests, CityInfillTests, WorldTraversalTests, TrafficSafetyTests, TransitAndNpcTests, VehicleDamageTests, TransportPhysicsTests, ScenarioTests, SimulationTests, CityLifeTests, LegalCareerTests, CareerWorldTests, LifeEconomyTests, DistrictEconomyTests, SocialSystemsTests; PlayerJourneyProbe uses real connected Studio players.
- This is a substantial **prototype source implementation**, not proof of shippable gameplay.

## Verified today
- Inspected actual current GitHub files for startup, release gate, map audit, profile schema, death/bounty, and career game flow.
- **Did not** run Luau, Roblox Studio, Rojo build, real multi-server DataStore, publish a place, device profiling or the scripted Studio test modules in this session.
- The presence of assertions is not a passing test result. Do not present old offline Python model checks or source-string checks as proof of integrated game function.

## Contract: >99% automation of a FIXED acceptance suite, with zero P0 defects
For planned release, define a versioned finite suite with at least 200 meaningful assertions, at least 150 of which directly exercise runtime game services in Roblox Studio or an engine-backed test environment. **At least 99% must pass, plus ALL P0/P1 money/data, join/respawn, exploit, map-surface and public-purchase checks MUST pass 100%.**
This is a coverage target, NOT an observed statistic. Test suites that never ran count as NOT EXECUTED, not PASS. A failure cannot be averaged away by thousands of easy static asserts.

### Mandatory full-game scenarios (all blocking)
1. **Fresh account:** 2–4 players join; unique home assignments; spawn on safe floors; each gets valid starting vehicle, wallet and garage; user onboarding works on mobile and keyboard.
2. **Rejoin/crash:** owner leaves while saving, rejoins another server, lease held/expired/corrupted/V1-V4 migration; no invisible vehicle, duplication or rollback.
3. **Drive lifecycle:** enter own car, deny чужой driver, accelerate/turn/headlights, physics reset after exit, wreck, fall off road, die, recall exact owned car to home; car must not duplicate.
4. **Urban geometry:** raycasts and swept vehicle/character paths at all route edges, bridges, curbs, interiors, tunnels, spawn pads, shops, beaches. Test positive/negative collision and StreamingEnabled cell loading; physics and seam checks on server and low-end client.
5. **Whole economy:** wallet/bank/home vault, clinic bill/medical debt, car and part shops, property deeds/rent, all legal career rewards, fishing, illegal goods and fence, bounty and safety dividend. Balance is conserved or accounted by explicit mint/sink event; no double reward when UpdateAsync callback is replayed or times out AFTER COMMIT.
6. **Occupations:** all 16 legal and 5 legacy jobs completed once with honest movement; invalid transport, teleport, timeout, car theft, death, parallel shifts, disconnect and repeated payout all fail safely.
7. **Crime→district→response:** actual witnessed/verified crime increases local heat; residents respond; law player protects neighborhood; bank trust/property price changes; arrest/death restores server state without awarding colluding crews.
8. **Multiplayer:** 2, 4, 8 and target server capacity, competing streetcars and NPCs; no cross-user DataStore mixup, theft of owned vehicle, race payout exploit or crew/territory double-claim.
9. **Client:** PC keyboard, gamepad and 2 Android screen sizes; camera, minimap, shops, interact prompts, accessibility, latency and graphics budget.
10. **Commerce:** developer products for purchased Robux-funded credits **not certified**. Must implement MarketplaceService.ProcessReceipt, durable unique PurchaseId journal, idempotent grant, receipt retry, no trust in client amount; staged real Roblox test before enabling payments.
11. **Operational:** no uncaught errors in 60-minute soak, NPC count capped, DataStore budgets respected, degraded-mode disconnect helpful, instrumentation for onboarding, currency sources/sinks and payment anomalies.

## Unified automated pipeline (no GitHub Actions required)
1. Pull/verify exact pinned commit; run `python3 tools/release_gate.py` (source validator + Rojo build). Fail if any tool unavailable.
2. Build and open private Roblox Studio test place. Run server bootstrap + all Luau suites with one reporter that records test ID, scenario, duration, PASS/FAIL/SKIP and exception.
3. Studio `Start Server` with 2–4 connected clients. Drive headless-friendly server-assisted scenario fixtures; DO NOT fake real client character/physics/network paths. Verify authoritative server snapshots after every transition.
4. Staging-only second server + Test DataStore namespace. Inject errors/timeouts/replays and verify atomicity; use dummy purchase receipts for unit tests, actual platform receipt staging for final approval.
5. Repeat smoke/soak with target load and memory/CPU/network budgets. Use graphics/device emulation, and schedule a small real hardware smoke pass.
6. Emit ONE versioned receipt `release-report.json` and human report for the same git SHA. Fail release unless no P0/P1 FAIL/SKIP, >=99% target suite PASS, and all required engine-based tiers executed.
7. Release only from the identical tested SHA, with private beta, rollback, data backup/recovery and versioned toggles.

## Remaining must-do engineering (ordered)
P0: actual Rojo/Luau build and runtime suite execution; collect machine PASS/FAIL from Studio; fix all discovered compile/start failures.
P0: true DataStore concurrency/timeout-after-commit tests for both personal and financial ownership; receipt processing before Robux monetization.
P0: autonomous real end-to-end tests in Studio (join→home→car→job→wallet→hospital→rejoin), plus world traversal on physical vehicle.
P1: physical and mobile performance/concurrency; NPC density, streaming and world seams under speed; recover from stalls.
P1: player-facing UX consistency, moderation/reporting, player privacy/security, anti-fraud for trade and bounty, logging and economy monitoring.
P2: final assets, animations, distinct car models, quests, district visual polish, accessibility/localization.
No percentage of **actual test passage** can be given until Studio and staging tests execute and produce a receipt.

## Suggested owner's short final acceptance (after automated green receipt)
20–30 minutes on an actual target Android device and PC: join, find home/car, drive city + wreck/recall, finish one lawful route, shop part, bank/medical, meet second player, view wanted board. This tests subjective fun/feel and visible polish, not thousands of developer regression cases.

**Release decision: HOLD. User should not have to perform the developer's QA.**
