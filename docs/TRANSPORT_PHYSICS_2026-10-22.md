# Sprint — Transport class physics and player fall response

Date: 2026-10-22. Branch: main. No GitHub Actions/CI.

## Implemented in this pass

- `src/shared/TransportSpecs.luau`: 9 distinct profiles: bicycle, motorcycle,
  dirtbike, truck, tractor, bus, speedboat, fishingboat, propplane.
- `src/server/services/TransportPhysicsService.luau`: authoritative seated
  control; input bounds, driver verification, rate limiting, timeout; separated
  road/cycle ground raycast and spring force, water detection/buoyancy, and
  speed-dependent airplane lift/stall. Server network ownership preferred.
  Per-class ballast approximates mass; specialized low-collision visual geometry.
- Placeholders are spawned on actual z=300 roads, Terrain water z=2124, and
  a simple reserved runway. Vehicle anti-void recovery exists.
- `src/server/services/CharacterPhysicsService.luau`: server-observed freefall
  duration/velocity and bounded fall damage, preserving normal Roblox R6/R15
  motors; spawn grace and seated protection.
- Client `TransportInput` wiring uses native `VehicleSeat` floats, retains
  original owned-car controller and mobile/keyboard driving actions.
- `TransportPhysicsTests.luau` asserts preset ranges, spawned vehicle parts,
  unanchored chassis, seats and force actuators in Studio.
- `tools/validate_project.py` includes the new files and static regression
  invariants; transport/character services start in the server bootstrap.

## Evidence and limits

- Verified the precise GitHub main paths and 10/10 static integration checks.
- No Roblox Studio Luau compile, vehicle playtest, terrain water test, two-client
  network verification or physics profiling was executed in this environment.
- These are **class-specific force-model prototypes**, not finished realistic
  vehicle physics. Existing owned cars still use four-ray spring approximations,
  with cosmetic welded wheels. New two-wheelers do not yet have independently
  articulated wheel constraints. Aircraft has an approximate lift/stall envelope
  but not 3-axis pilot control or actual aerodynamic surfaces. Boats use terrain
  water detection, not a calibrated hull displacement fluid solver.
- Add proper bike hinge wheels/gyroscopic lean, axle/differential/drivetrain,
  trailer coupling, 6DOF plane flight controls, underwater/propeller forces,
  low-end Android profiling, edge-of-map recoveries, collision/slope QA and
  realistic animations before treating the system as commercial quality.

**Release status: blocked pending real Roblox Studio testing and class-specific refinement.**
