# Street City Online

Roblox multiplayer open-world game. **Current milestone: playable engineering prototype**, not public release. The first slice creates a small deterministic city blockout and one shared drivable test car. No paid purchases, profile storage, deep tuning, traffic, or Cube 4D are claimed as implemented.

## Run locally

1. Install [Roblox Studio](https://create.roblox.com/) and [Rojo 7](https://rojo.space/).
2. Clone the repository and run \`rojo serve default.project.json\`.
3. Open a new **Baseplate** place in Roblox Studio, **delete its default Baseplate and SpawnLocation objects**, install the Rojo Studio plugin, and **Connect** to the local Rojo server. The prototype creates its own ground and spawn point.
4. Press **Play**. A procedurally created test district, spawn point and a test car appear. Walk to the car and use the proximity prompt to drive. Use **L** (or the touch action) to switch headlights.
5. For a repeatable build artifact, run \`rojo build default.project.json -o StreetCity.rbxlx\` and open it in Studio.

Test **Server & Clients** with 2 players, and check the Output panel for \`[StreetCity]\` messages. The project has no CI or GitHub Actions; it has not yet been playtested inside your Roblox account.

## Technical direction

- \`src/server\`: authoritative systems, world generator and car simulation.
- \`src/client\`: lightweight player HUD and action bindings.
- \`src/shared\`: contracts/configuration and deterministic simulation math.
- \`docs/\`: design, roadmap, manual verification gates.
- \`main\`: direct commits; publish to Roblox **manually only after staging tests**.

Do not place credentials in the repository. Roblox 3D assets and the Cube 4D integration will be developed in later sprints. Read [architecture](docs/architecture.md), [roadmap](docs/roadmap.md) and [quality gates](docs/quality.md).
