# Integrated city audit — 2026-10-22

Current branch: main. Source review and GitHub file verification, not an executed Roblox Studio playtest.

## Systems inspected

- Road agent: WorldService continuous asphalt panels, terrain chunks, perimeter, water.
- Environment agent: StreetDetailService sidewalks, lanes, crossings and streetlights.
- District/art agent: DistrictService blocks, CityArchitecture façades, CityLandmarkService civic plazas.
- Gameplay agent: TrafficService autonomous civilian/police fleet; HousingService homes, rescue and personal garage points.
- QA agent: Studio WorldTraversalTests and StartupContract.

## New fail-closed acceptance

Implemented `src/server/services/WorldSurfaceAudit.luau` and invoked it just before `StartupContract.Validate()`.

It raycasts ~1,200 real-world collision samples across grid-axis road panels, seam overlaps, seven district centers, all 48 personal garages and all 48 home respawn positions. Roads must actually return flat asphalt, not a facade, decorative sign, ocean or missing ground. A home spawn needs a valid stable collision surface. Missing pieces stop the server before it prints a ready message.

`tools/validate_project.py` now requires the collision acceptance module and correct bootstrap ordering. Existing Studio `WorldTraversalTests` continues to inspect 48 walkable homes, district building clearances, 49 road samples, and decentralized traffic fleets.

## Known limitations / next gates

- Source review is not equivalent to Roblox Studio runtime execution: actual raycast results and frame-rate need testing.
- Art assets still include generated/faceted placeholders, not hand-produced AAA neighborhoods.
- City has no global cross-server shared NPC traffic/land ownership simulation.
- Traffic uses bounded rule-based waypoint following, not robust navmesh avoidance.
- Terrain chunk creation and hundreds of building/sidewalk Parts need MicroProfiler measurements on low-end mobile.
- Publish only after Rojo compile, two-client Studio tests, low-end Android profiling, and DataStore tests.

**Release decision:** no claim of a fully final commercial game until runtime gate and device tests pass.
