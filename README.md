# Street City Online — Roblox open-world life simulator

**Status: multi-system development prototype in source, not a public release.** Roads, cars, racing and garage are the initial gameplay loop. Future city activities may include property, jobs and more; those have **not** been implemented.

## Getting started (no CI / GitHub Actions)

1. Install Roblox Studio and Rojo 7.
2. Clone this repository; run `rojo serve default.project.json`.
3. In Roblox Studio, open a fresh Baseplate place, **delete its stock Baseplate and SpawnLocation**, install the Rojo Studio plugin and connect.
4. Press Play; the server generates a small test city and blockouts for seven districts.
5. In **unpublished Studio**, the profile is explicitly temporary and stored only in server memory. A shared test car and personal cars are available. Progress disappears when the test session ends.
6. Drive your own car through the green race-start marker to begin a solo time trial. Follow yellow numbered checkpoints. Finishing with valid movement earns **650 credits**.
7. At orange garage-shop stands, buy new or used parts with earned credits. Use the install stand when parked and outside the car. A blue personal garage terminal switches between owned cars if multiple exist.
8. Check the Output panel for `[StreetCity]` errors and smoke-test assertions. Use **Test -> Server & Clients** for multiplayer checks.

For a build file (requires locally installed Rojo):
```sh
rojo build default.project.json -o StreetCity.rbxlx
```

**Runtime acceptance has NOT been run here.** Luau compiler, Rojo and Studio are not available in this environment. Do not publish the public game, accept Robux, or trust persistence until all release gates are passed.

## Architecture

- `src/shared`: data catalogs, profile schema V2 with V1 migration, drivetrain and economy rules, race validation.
- `src/server`: authoritative car controls, player garage, DataStore sessions, credit shops and race checkpoints.
- `src/client`: speed display, light controls, driver input transport and minimal balance/notifications.
- `docs/`: engineering decisions, active sprint receipts, roadmap and validation requirements.

In published Roblox staging the persistent DataStore is used. Unpublished Studio uses sandbox-only profiles. The shared free test car is disabled outside unpublished Studio.

Prioritize: vehicle handling tests, profile contention testing, real mobile controls and the first fully playable loop before expanding the world. See [roadmap](docs/roadmap.md), [architecture](docs/architecture.md), and [current acceptance checklist](docs/sprints/SPRINT_07C_08_10.md).
