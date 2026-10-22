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
