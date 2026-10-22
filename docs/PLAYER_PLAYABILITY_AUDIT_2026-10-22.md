# Actual player playability audit — 2026-10-22

Repository: `venomimonstro/roblox-new-city-life`, branch `main`.
**Decision: source-level basic gameplay is wired, but real playability is NOT verified; no public launch.**

## Evidence obtained from this audit

1. Inspected the current `main` server bootstrap, world/surface checks, home/garage/profile services, driving input and career systems.
2. GitHub's complete default-branch tree contains **all 85 files** currently listed under `REQUIRED` in `tools/validate_project.py`; this proves presence, not successful import or compilation.
3. Ran a source-derived deterministic geometric check of **48 home garage positions**: 48 unique, no garage point on the road centerline; source uses deterministic player-specific home allocation with collision resolution for concurrent players.
4. Inspected **16 legal career routes**: each has two distinct orthogonal segments in its source catalog. Rewards, movement timing and ownership validation exist in server code. Separate legacy jobs and fishing exist; no actual player completed these in Roblox during this audit.
5. The runtime bootstrap starts services in a controlled order, validates actual road geometry and asserts world/NPC/UI prerequisites before claiming readiness.
6. The environment in which this review ran has **no Roblox Studio, Rojo or Luau compiler** and cannot access GitHub with local git. Therefore **NO Rojo build, Luau runtime suites, multiplayer game sessions, physical car tests, production-persistence tests or mobile benchmarks were executed**. This is a substantive blocker, not a cosmetic disclaimer.

## Confirmed source defects fixed now

- Previous Studio sandbox check was only `RunService:IsStudio() and game.GameId == 0`. Testing an already published place from Studio could unintentionally use live player DataStore. Now **Studio defaults to memory-only profiles for all Studio places**; a separate private test place must deliberately opt into persistence via `StreetCityAllowStudioDataStore=true`.
- Personal garage `Recall` used to reposition a mechanically destroyed (`VehicleHealth <= 0`) personal car, making it unusable indefinitely until death. Now a recall replaces this zero-health chassis with a fresh vehicle whose ownership, configuration and parts come from the validated saved profile.
- Added `src/server/dev/PlayerJourneyProbe.luau` and wired it to the Studio bootstrap. It checks **real connected players** (not fake accounts) for: loaded profile, assigned home, living character near home, physical ground, personally owned and selected car, non-destroyed chassis, and driving/career communications. It prints either `[StreetCity Playability] PASS` or detailed `FAIL` messages.
- Replaced outdated README claims that jobs were not built and outdated DataStore testing advice with an explicit current Studio procedure and limitations.

## User journey acceptance matrix

| Player action | Source implementation | Studio acceptance |
| --- | --- | --- |
| Join and spawn next to personal home | wired, 48 home slots per server | unexecuted |
| Living avatar stands on real ground | character relocation, terrain collision checks and void rescue | unexecuted |
| Personal starter car appears in garage | profile + garage service + owner validation | unexecuted |
| Drive PC/phone/controller | client/server remote and movement logic present | unexecuted |
| Streets/seams traversable with 2+ cars | connected road generator and startup raycast audit | unexecuted |
| NPC traffic, stealing and wanted stars | authority checks and NPC code present | unexecuted |
| Race -> payout -> shop -> install -> recall | server credit and idempotency logic present | unexecuted |
| Legal job -> move to checkpoints -> wages | 16 two-stop careers + legacy jobs present | unexecuted |
| Die -> home respawn -> medical cost | recorded economic rules, respawn paths present | unexecuted |
| Logout/rejoin with money and property | profile lease + DataStore code present | unexecuted |
| Two people get distinct plots and cannot drive other's car | server source guards present | unexecuted |
| Android performance, streaming, GPU and physics | no measured FPS or live client receipts | unexecuted |
| Public Roblox place accessible by game link | no published-place ID or successful live session verified | unverified |
| Developer-product Robux -> credit issuance | real-money purchase receipts not accepted | BLOCKED |

## How to obtain a real pass/fail

Run, in a full cloned checkout:

```sh
python3 tools/release_gate.py
rojo build default.project.json -o StreetCity.rbxlx
```

In Roblox Studio open the built place, remove the stock Baseplate/SpawnLocation from the source place before syncing if using Rojo Serve, and launch Play; inspect Output for:

- `[StreetCity Surface] PASS` (collisions/road sample)
- `[StreetCity Gate] PASS` (all required world and remote objects)
- `[StreetCity Playability] PASS: user <id> ...` (real player and owned car)
- Studio suites `[StreetCity] PASS ...` and zero errors/warnings for critical flows

Repeat with 2 clients, Android, private published staging and an explicit persistence opt-in. A passed gate still requires driving, race, credits, death, purchase and rejoin verification; source tests are not a substitute for observed gameplay.

**Decision: a developer can attempt a local Roblox Studio playtest from this repository after a clean Rojo build. A normal player cannot yet be promised a working published game or full GTA-like gameplay.**
