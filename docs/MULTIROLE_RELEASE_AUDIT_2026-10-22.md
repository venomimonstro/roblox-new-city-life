# Multirole audit — Street City Online — 2026-10-22

Target branch: `main`. No GitHub Actions. Release decision: **HOLD**.

## Roles and inspected production journey

| Perspective | Scenario | Findings / safeguards |
|---|---|---|
| New player | Join → home → garage → start free owned car | Profile V4, residential mapping and owner checks present; real two-client Studio run is required |
| Driver | Drive, park, traffic, collisions, district traversal | Surface raycast contract exists; cannot prove high-speed/stressed collisions without Roblox physics |
| Worker | 5 initial jobs and 16 multi-stage careers → credits | Job overlap is prevented by one shared registry; per-stage time/motion constraints and idempotent operation IDs are in source |
| Mobile player | Enter owned car → shift → park → collect salary | UI server route notifier exists; physics and touch acceptance still pending |
| Economist | Repeated shift start/finish; fish sales; vehicle and part purchases | Cross-provider shift lock, reward journal and pending fish latch present; cross-server ambiguity is not fully solved by a 40-operation journal |
| Healthcare | Defeat → hospital fee → debt → free respawn | Hospital debt and home-safe controls exist; no mandatory Robux payment |
| Sheriff | Wanted posters, bounty target, crew collusion | Server-only attacker attribution and anti-repeat windows exist; real PvP tests still pending |
| Security reviewer | Spoof remotes, drive unowned car, claim absent job, leap to goal | Server car ownership checks and work travel proofs exist; not a penetration test |
| Environment/QA | All job stands and fish market have reachable ground | NEW Studio-only `CareerWorldTests` raycasts every start/destination and fishing terminal |
| Release engineer | Boot fails closed when essential gameplay missing | `StartupContract`, `WorldSurfaceAudit` and the source validator are wired; no actual Rojo build was run here |

## New code in this pass

- `src/server/dev/CareerWorldTests.luau`: checks all 16 career starts, all 32 career destinations and 13 legacy job/fishing spots, totaling **61 floor-point inspections**. Verifies real collision surface, elevation and floor slope.
- `src/server/bootstrap.server.luau`: wires this Studio acceptance test before readiness is announced.
- `tools/validate_project.py`: requires the test source and bootstrap wiring.

## Verified this session

15/15 targeted **GitHub source-integration invariants** passed against the current `main`: boot ordering, raycast test wiring, mission movement checks, payout idempotency, a single shift across job providers, lock release, taxi owner identity, fishing payout latch, the HUD RemoteEvent contract and regression coverage.

These are **source consistency checks**, not proof of Lua parsing, physical gameplay or DataStore outcomes. No actual Studio tests were executed. There is no reliable evidence that every project sprint has passed its acceptance criteria.

## Known launch blockers

1. Successful `rojo build` and Luau static/typecheck diagnostics in a complete local checkout.
2. Execute all Studio suites, including `CareerWorldTests`, `SmokeTests`, `LifeEconomyTests`, `LegalCareerTests`, and traversal suites.
3. Multiplayer 2–4+ device play sessions, death/rejoin/seat handoffs, Android touch and gamepad.
4. Published private test with DataStore contention, ambiguous `UpdateAsync` outcome, shutdown and crash recovery; avoid real purchases.
5. Benchmark city world with traffic, streaming, many cars, phones and low-end hardware.
6. Production-grade persistent property title, crew influence and consistent cross-server district state, plus moderation and retention; this is not solved by local session state alone.

**Do not call this a fully final Roblox game yet.** Source defects are being fixed and source acceptance expanded, but release readiness requires empirical runtime evidence.


## Additional release-blocking corrections — transport, parser and bounded startup

This additional audit pass found actual defects in production and Studio QA, not just incomplete feature lists.

- **Economy / transport P0:** public transit debited tickets before confirming a usable destination floor. Paid rides now require a walkable preflight; both underground and street transfers perform raycasts and avatar-volume obstruction checks. If a paid ride cannot complete while the player is online and loaded, a distinct refund operation with stable identifier can return the fare. A successfully arrived player is never refunded because of a later UI notification error.
- **World / collision P0:** a landing ray must ignore car roofs as floor while also rejecting traffic vehicles as obstacles. Metro entrance and exit now use the same grounded, clearance-checked landing path. Studio acceptance checks each metro and bus destination and injects a deliberate blocking pillar.
- **QA / compilation P0:** `TransitAndNpcTests.luau` previously had a missing comma in an `assert` statement for NPC identity. Corrected. Added a static regex guard in `tools/validate_project.py` for this recurring class of Luau error.
- **Boot / operations P0:** each of the 41 server service imports now goes through a 10-second bounded loader. A missing ModuleScript produces a named fatal bootstrap message rather than an indefinite `WaitForChild` yield.
- **Regression flakiness:** Studio terrain tests ignore moving vehicles **only for test instrumentation**; production landing clearance still rejects occupied positions.

### Evidence actually checked

- All **41 of 41 required service paths** found in GitHub `main`; source inspection only.
- All **16 Studio acceptance-suite source files** inspected for the specific missing-comma assertion pattern. One corrected; not a full Luau compiler.
- **14 of 14 focused static post-change checks** passed for launch wiring, fare-before-floor prevention, compensation, both metro exits, occupied landing, source lint guard and Studio fixture wiring.
- **16 of 16 previously created Python state-machine tests** ran successfully on the older independent economy model. The model does not execute present-day Roblox/Luau source and must not be used to certify current game behavior.
- **Not executed here:** Rojo build, Luau compiler, Roblox Studio Play, mobile client, two-server DataStore, published staging, production receipts and concurrency/profiling. They remain release blockers.

### Follow-up security correction: delayed ticket exploit

Subsequent adversarial review identified an additional paid-transport vulnerability:

1. A rider could book transit near a station, leave its area during the departure delay and still teleport to a different part of the city.
2. The fare was previously taken at booking, making pre-departure death, disconnect and cancellation financially unfair.
3. A departing Player instance could clear a newly joined instance's pending ticket because state was keyed only by UserId.

**Corrected in code:** station reservations are initially free, the actual passenger and current distance from the origin are revalidated at departure, funds are charged only then, destination collision is revalidated after the yielding DataStore call, and individual tickets use a unique operation token so stale callbacks cannot touch newer reservations. If a charge commits but arrival becomes invalid, compensation is a separate idempotent write with an immutable refund ID.

**Release check:** `validate_project.py` now checks departure ordering, station proximity and UserId ticket isolation. Real in-engine quit/rejoin simulation and two-server transfer consistency remain mandatory and unexecuted.

### Release decision

**HOLD — not final commercial release.** The game now contains stricter source safeguards, but no Roblox-engine proof that the live player journey is stable. Optional Robux currency purchases must remain disabled until durable, tested `MarketplaceService.ProcessReceipt` handling exists. Global uniqueness of properties and cross-server territory control remain unverified/incomplete. Do not interpret a static gate or checked-in sprint as production acceptance.
