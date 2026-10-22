# Street City Online — city visuals and collision audit
Date: 2026-10-22. Branch main. No CI.

## Implemented
- District buildings: differentiated palette, facade windows, mullions, roof caps and storefronts; 55 solid building cores remain authoritative for collision.
- Residential area: 48 house plots with pitched roofs, window frames, animated owner-only front doors, solid roofs, walkable floors and garage detailing.
- Removed duplicate facade pass and duplicate district sidewalks: one street system is responsible for collision.
- Moved beach and sea away from driving lanes; water is real Terrain water, not only a glass sheet.
- Continuous Terrain now extends to +/-2304 studs, streets to +/-1820; world-edge safeguards at +/-2265.
- Fixed fishing pier and market at waterfront.
- Gave residential spawns room outside house walls.
- Consolidated redundant avatar fall-through recovery; owner cars tunnelled below terrain return to garage with reset movement.
- District startup gate requires real facade models and functioning home roofs, doors and floors.

## Offline geometric checks actually executed
- 280 asphalt sections; 40 studs overlap at each section joint, no numeric road seam.
- 55 buildings in seven districts; no street collision overlap, minimum 22.5 studs clearance.
- 48 distinct homes, minimum garage-to-road clearance 3 studs; house-to-garage clearance 7.5 studs.
- Sidewalk inner edge 0.1 studs beyond asphalt edge; perpendicular crossings lie below asphalt height.
- Terrain buffer past asphalt ends: 484 studs; far boundary minimum 437 studs beyond terminal asphalt.
- Beach begins at z=1837.5; real water begins at z=1944, beyond traffic lanes.

## Studio-only tests added but NOT executed
- src/server/dev/CityTraversalTests.luau: inspects 280 asphalt segments, raycasts 289 junctions, probes all 48 garages, checks building facades, water and world borders.
- Updated src/server/dev/WorldTraversalTests.luau to expect a real interactive front door rather than an open collision hole.
- StartupContract and tools/validate_project.py reject missing collision protections and duplicated recovery systems.

## Production limitations
- Buildings, roofs and vehicle bodies are optimized procedural low-poly models, NOT final professional MeshParts/PBR assets.
- Unrealistic flat terrain outside the handcrafted neighborhood and true suspension remain content gaps.
- No actual Rojo compilation, Roblox Studio live multiplayer test, low-end mobile profiling or scene screenshot has been executed here.
- The game map is finite; physical border must eventually be supported with authored landscape art.
- Release decision: HOLD until Studio scene tests and on-device driving are confirmed.

Run locally: python3 tools/release_gate.py
Then run Studio Play to see both CityTraversalTests and WorldTraversalTests, drive across city road joints, walk into your home, test sprint on Android and swim at the shore.
