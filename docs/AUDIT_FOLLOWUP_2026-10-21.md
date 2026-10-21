# Audit follow-up — session locks, race settlement and server performance

Date: 2026-10-21. Status: source changes committed to main, unverified in Roblox runtime.

## Corrected in this follow-up

1. ProfileService.Save previously referenced `output` outside the UpdateAsync retry loop. A successful save/lease renewal could then fail to refresh the cached data. Confirmed records are now captured as `confirmedData` inside the loop and applied only after a validated response.
2. An uncertain mutation used to drop the local profile completely before kicking the player. That prevented PlayerRemoving from attempting to release its lease, potentially blocking quick reconnects. Sessions now enter quarantine: IsLoaded/Read/Mutate reject access while Save(release) retains a best-effort owner-token guarded release path.
3. Heartbeat renewal failure also enters quarantine instead of immediately discarding the profile, preserving the ability to release if a subsequent DataStore call succeeds.
4. A parked owned car is reconfigured in place rather than overlapping two rigid bodies during a switch.
5. RaceService prevents concurrent races during an asynchronous credit settlement.
6. Server driving force/raycast recomputation is capped at approximately 30Hz instead of running on every heartbeat. This is a **performance design choice**, not a measured performance result.
7. tools/validate_project.py now detects regressions in these critical source invariants without CI.

## High-risk acceptance scenarios

- [ ] Staging DataStore: normal, cancelled (insufficient credits), timeout-after-commit, lock stolen, three consecutive renewal errors, owner-token release and quick reconnect.
- [ ] Two published staging servers competing for one account: only one active writer, no duplicate credit settlement.
- [ ] Delayed race reward: attempt to start a second race while the first write is unresolved; no parallel paid runs.
- [ ] Car switching: parked/stopped vs occupied/moving, saved tuning matches live attributes without collision spikes.
- [ ] Studio multiplayer with 2–4 clients, client steering on Android, latency + disconnect, lights and owner checks.
- [ ] Profile vehicle raycast workload, server CPU at target max player count; compare ~30Hz update against baseline in MicroProfiler.
- [ ] Rojo build and Studio Luau diagnostics (not available in this environment).

## Remaining release blockers

- Independent suspension/wheels, complete and collision-safe streets, polished mobile UI, NPC traffic.
- Persistence recovery, long-lived idempotent purchase receipts and session lock failover need staging integration tests. A bounded 40-ID journal is not sufficient for Robux purchase processing.
- No actual Rojo compilation, Roblox Studio playtest, production publish, or security penetration test has been performed.

No GitHub Actions / CI. Production release remains blocked.
