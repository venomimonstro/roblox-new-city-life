# World, traversal and visual upgrade — 22 October 2026

Status: source changes committed directly to `main` without GitHub Actions.

## Implemented in source
- Residential lots: 48 separate active home locations. The opaque solid "House" block is now an invisible noncolliding locator and **real wall, floor and front doorway** segments. Existing authored facade details include sloped roof panels, glazing and garage trim. New garden hedges, yard trees and mailboxes have no query or collision.
- City: `StreetDetailService` provides 560 road-aligned sidewalk segments, 560 noncolliding line paint sections, 196 zebra road markings at populated intersections, 28 decorative lamp posts + 28 lamp heads, and street signs for seven districts. Each decorative part avoids acting as vehicle suspension ground.
- `DistrictDetailService` no longer adds a second set of windows or road stripes over `CityArchitecture`; it only retains storefront identity and localized district lamps.
- Vehicles: extra cab roof, mirrors, rear window, grille, bumpers, rear lamps and a starter pickup rail. Cosmetic car parts have `CanQuery=false` and `CanCollide=false`.
- Running: `SprintService` drives stamina (0–100), a server speed ceiling of 25 studs/s, nutrition/fitness speed baseline and exhaustion cooldown. Mobile (RUN), Shift and gamepad L3 controls use a *boolean intent only*. Releasing the input always cancels sprint, even after a quick tap.
- Navigation: each player receives their **own session-assigned** residential coordinates and a distance-to-home cue when exploring.
- Failsafe: a living avatar found below Y=-45 is moved to its designated home without wrongly incurring a hospital charge. If driving, the abandoned personal car recovery callback is invoked.
- Startup contract and a new Studio-only `WorldTraversalTests.luau` suite verify streets, collision-safe art, road panel seams, walkable house entrances, fitting garage footprint and terrain beyond asphalt.

## Independently executed model checks
The geometry model verified:
- 48 unique residential home coordinates, minimum lateral gap from the road driving envelope **11.8 studs**.
- Four adjacent road segment intervals `[-1820,-880]`, `[-920,20]`, `[-20,920]`, `[880,1820]` overlap by **40 studs** at every join.
- With the current 2304-stud terrain extent, every asphalt endpoint at +/-1820 retains **484 studs** of ground beyond it.
- 55/55 configured blockout building centers clear their closest road lane envelope by 22.5 studs under the procedural layout rules.
- The current GitHub sources passed 25/25 source integration invariants for this upgrade at the time of audit.

**None of the above means Roblox Studio compilation, driving physics or mobile FPS has been tested.** The `WorldTraversalTests` module is wired but must be executed in Studio; the tests describe expectations, not obtained runtime PASS results.

## Remaining visualization and driving blockers
- Built-in Roblox Parts and Glass/Slate/Brick materials produce more consistent architectural *prototypes*, but are not photorealistic or final AAA-quality assets. Import properly licensed, optimized custom home/car/environment MeshParts and PBR SurfaceAppearance maps. Keep their collision bounds separate from cosmetic meshes.
- Original city buildings still contain a single collision core, with simulated facade detail. Their interiors are not implemented. Residential home doorways are walkable; fully furnished interiors require an authored prefab pipeline.
- Car tires are still welded cosmetic wheels and the chassis uses a provisional server arcade/suspension model, not an independently constrained production vehicle rig.
- Roblox Studio Lua diagnostics, multiplayer network simulation, low-end Android / gamepad movement, and server frame profiling remain unperformed here. No public release approval.

## Manual commands (no CI)
```bash
python3 tools/release_gate.py
rojo build default.project.json -o StreetCity.rbxlx
```
Then launch the place in Roblox Studio and review output from `WorldTraversalTests`, `SmokeTests`, `CityLifeTests`, other scenario suites and the production startup contract. Do not mark a pass without actual runtime evidence.
