# Street City Online — city generation, walking/driving and low-end graphics pass
Date: 2026-10-22. Branch: main. No CI/GitHub Actions.

## Implemented in this pass

1. `CityInfillService.luau`: reproducible seeded parcel infill in seven existing districts. The center city receives up to 22 extra buildings; most other districts up to 16; village up to 12 (118 maximum additional structures). Objects are offices, flats, retail, condos, brick homes, abandoned buildings, workshops, warehouses, hotels, lodges, etc. Distinct district styles and rooftop features.
2. Every new building checks horizontal parcel occupancy with `Workspace:GetPartBoundsInBox` before creation and never occupies the 25-stud asphalt lane; important physical structures and interactive ProximityPrompt objects reserve lots. Exactly one anchored collision shell per infill building; windows, roof lips, awnings and HVAC decorations have no collisions, no raycast/query and no touch signals.
3. Infill models and existing building façade models use `Model.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM` so distant decorations do not require the whole authored geometry on low-memory clients. Roblox `Workspace.StreamingEnabled` remains enabled in the Rojo project. This is not a replacement for running a memory profile.
4. `MapHUD.client.luau`: lightweight local minimap with procedural road lines, current player orientation, home marker, career destination indicator, nearest district, no image downloads and no map synchronization network calls.
5. Manual device-oriented client settings: Performance, Balanced, Visual. Performance disables local rain particles and local shadows/post effects; Balanced reduces rain intensity; Visual can enable moderate bloom and sun rays. These are only client-side rendering preferences; no collision authority changes.
6. `WeatherService`: restrained atmospheric haze and daytime lighting, optional bloom and sun rays off by default. Do not claim photorealistic graphics from this alone.
7. `HousingService`: `Player:RequestStreamAroundAsync(home, 5)` before home relocation and cleared character momentum. Players face the direction of their own garage after spawning to make onboarding intuitive.
8. Existing server-start checks now require procedural infill count in a bounded range, and Studio-only `CityInfillTests` checks that all seven zones exist, building collision count exactly one per structure, setbacks from driving roads, cosmetic pieces nonphysical and live asphalt raycast samples.
9. `tools/validate_project.py` includes all new files and correct executable-source checks, not comment wording.

## Executed here (not Roblox runtime)

- Inspected 13 current repository files and checked 20 source integration invariants. One original test string mismatch was repaired in the validator; all relevant invariants can now be rechecked against actual source.
- Independently calculated legal candidate parcels from source offsets and coordinates: 112 before occupancy filtering in six districts, 101 in the edge mountain district. Each candidate building's maximum half-width (16.5 studs) retains 21 studs of clearance from the road centerline after accounting for road half-width 12.5; existing buildings, housing and work objects are subsequently filtered by runtime overlap.
- Direct container `git ls-remote` failed due missing DNS access to GitHub. `rojo` and `luau` command binaries were not available. Therefore **Luau compilation, actual Rojo build, Studio play, real multiplayer and device FPS were NOT verified.**

## Required release acceptance in Roblox Studio

1. Run `python3 tools/validate_project.py` and `python3 tools/release_gate.py` on a full local checkout with Rojo installed; exit must be 0. The latter only proves Rojo place build, not gameplay.
2. Load place in Studio, press Play, check `[StreetCity Gate] PASS`, `[StreetCity Surface] PASS`, `[StreetCity] PASS` from CityInfillTests, all old gameplay tests and Luau diagnostics. Fix failed cases before public publishing.
3. Spawn one player at each home row, enter home, open door, run from porch to garage, obtain owned car, leave and return; repeat with two players and Android.
4. Test drive across all seven districts at max practical speed, drive each seam (including old +/-900 panel joins), turn at narrow intersections, run on sidewalks, jump and fall, test respawn and recovery. Watch for foot/car collision, roof entry and streaming pause.
5. Sample `Stats` and `MicroProfiler` on a low-memory laptop and an Android handset for 2, 8, and maximum players, including concurrent cars, pedestrians and live traffic. Target stable >=30 FPS on baseline hardware; 60 FPS on reasonable desktops is a goal, **not yet measured**.
6. Profile actual client instance count, GPU render and memory. If excessive, reduce façade ornament floors, distant landmarks and rain first; never disable world collision to artificially improve FPS.
7. Review Studio Workspace streaming parameters per Roblox guidance: `ModelStreamingBehavior=Improved`, `StreamingIntegrityMode=PauseOutsideLoadedArea`, `StreamOutBehavior=Opportunistic`, `StreamingMinRadius=64` and choose TargetRadius appropriate for visuals/device. These properties are not all script-settable and should be configured/confirmed in Studio for the published place.
8. Replace box-based vehicles, billboard façades and low-poly roofs with licensed game-ready meshes, materials, animations, foliage and interiors. Photorealistic AAA city graphics cannot be established by these procedural primitives alone.

## Non-goals / safeguards

- No forced downloads, Studio plugins, CI jobs, paid tool calls or third-party unlicensed assets.
- The generated parcel topology and seven-district road network remain server-authoritative. The minimap derives only geometry and player position locally.
- This changes city presentation and parcel density, not economy, purchases, PvP damage or DataStore schema.
- **Release status: source upgraded, Studio acceptance blocked.** It is an improved Roblox world prototype, not a validated GTA VI-grade AAA release.
