# Street City Online — Roblox open-world game prototype

## Automated whole-game release acceptance (no CI)

On a local workstation with **Roblox Studio** and **Rojo**, run:

```sh
python3 tools/run_full_acceptance.py
```

This runs source checks, builds the Rojo place, starts Studio with **two simulated Roblox clients**, executes all **16 Luau Studio suites**, and checks actual player homes/cars, both client interfaces, hospitalization, free respawn and isolation between accounts. It writes `street-city-acceptance.json` and `street-city-acceptance.log`, and **fails closed** on missing tools, failed tests, absent receipts or timeout.

**Important:** This automated runner has been authored but not executed within the assistant environment. A source validation pass does not mean the game is approved for commercial launch. Multiplayer DataStore faults, mobile frame-rate and paid Robux receipts have separate blocking gates.

See [Commercial release audit — 2026-10-24](docs/RELEASE_READINESS_2026-10-24.md) for sprint statuses and remaining acceptance tests.


**Current status (22 October 2026): extensive game source and Studio tests, NOT a verified playable public release.** Player homes/garages, cars, roads, district NPCs, open-world traffic, legal careers, races, crime, police, shops, in-game credits, fishing, nature, transit and local social systems are implemented at different prototype levels. They have **not** passed an end-to-end Roblox Studio, live multi-client and DataStore acceptance.

## Actually try the game (no GitHub Actions/CI)

1. Install Roblox Studio, Rojo 7 and the Rojo Studio plugin.
2. Clone this repository. In the repo run `python3 tools/release_gate.py`. **This must pass.** If Rojo is missing, the gate returns an error, not a false PASS.
3. In a new Roblox Studio place, delete its default Baseplate and SpawnLocation, then use `rojo serve default.project.json` and connect the Studio plugin. Alternatively run `rojo build default.project.json -o StreetCity.rbxlx` and open the built place.
4. Press **Play**. Roblox server services dynamically construct the city. Look in **View → Output** for `[StreetCity Gate] PASS`, `[StreetCity Surface] PASS` and individual Studio suites.
5. The new `[StreetCity Playability]` probe checks the **actual connected test player**: live character, assigned home, ground, matching saved personal car, driving remote and job waypoint remote. **Only `PASS` for your player counts toward basic spawn acceptance.** It does not prove the driving physics.
6. Walk out of your house, find your personal vehicle in its garage, enter the driver's seat and drive. Test a complete race, one legal driving career, one foot career, parts purchasing, car recall after destruction, death/home respawn, and the city bank. Do not assume feature availability just because a model or stand exists.
7. In **Test → Server & Clients**, start two clients. Confirm distinct home plots, ownership locks, independent wallets, traffic and mutual visibility.
8. Run separate **published private staging** tests for real DataStore persistence across rejoin and server hops. Use **test accounts and a separate staging place**, never a production account by accident.
9. Repeat on a low-end Android phone and gamepad; profile FPS, replication, memory and road/terrain collisions across all seven districts before public release.

### Important data protection

**All ordinary Roblox Studio Play sessions now use memory-only profiles by default**, including Studio tests of an already published place. Money, cars and jobs earned there are temporary. To *deliberately* test persistent DataStore, use a separate private staging place and set the DataModel boolean attribute `StreetCityAllowStudioDataStore = true` before the server starts. Ensure Studio API access is enabled and never connect that test to production player wallets.

Outside Studio, the project uses the Roblox DataStore with session leases. Real DataStore compatibility, safe rejoin after outages and cross-server consistency remain unverified.

## Release blockers

- Rojo build, Luau diagnostics, actual Play and the startup/playability suites still need **runtime execution** and receipts.
- Multiplayer ownership, physical vehicle handling, NPC travel, real mobile controls, teleport safety, jobs and credit transactions need observed end-to-end acceptance.
- Persistent wealth, live DataStore concurrency and all real-money receipts must be validated before opening purchases or a public launch.
- Global player-owned property/title transfer and cross-server district politics are not production-ready.

**The game is a development prototype. A full commercial release is blocked.** See [global acceptance matrix](docs/GLOBAL_ACCEPTANCE_MATRIX_2026-10-22.md) and [playability audit](docs/PLAYER_PLAYABILITY_AUDIT_2026-10-22.md).

## Architecture

- `src/shared/`: schemas, catalogs, pure driving, economy and mission rules.
- `src/server/services/`: Roblox-authoritative city, player homes, profiles, cars, economy, jobs and NPCs.
- `src/server/dev/`: Studio-only suites including `PlayerJourneyProbe.luau`.
- `src/client/`: player HUD, controls and minimap.
- `tools/release_gate.py`: local source and Rojo build gate; **not** a Roblox runtime test.

Do not add GitHub Actions or CI for this repository.
