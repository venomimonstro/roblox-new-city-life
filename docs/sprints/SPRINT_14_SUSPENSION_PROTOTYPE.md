# Sprint 14 — four-point suspension prototype and update efficiency

Implemented in source:
- Four downward ground contacts per vehicle instead of a single central ray.
- Bounded, averaged vertical spring/damper force through a dedicated server-side VectorForce.
- Traction proportional to contact count and ground materials.
- Wheel point offsets reused each physics frame; no per-frame offset table allocation.
- Pure calculation smoke assertions for wheel count, spring compression and damping.

Not yet a finished physics system:
- Cosmetic wheels are still welded; there is no independent articulated wheel suspension, tire deformation or true corner-specific force application.
- Spring force is applied at center of mass, so pitch/roll behavior requires design and testing.
- Raycast count increases to 4 per car per heartbeat; 12-player/server profiling is mandatory.
- Studio verification, dual-client synchronization, mobile driving, jumps and slopes remain outstanding.
- Full sprint 14 (LOD, streaming, memory budgets, low-end device profiling) is NOT complete.

Release gate:
1. Open a Rojo build in Studio and inspect server output.
2. Validate driving over road, sand, grass, curb, ramp and airborne sections.
3. Measure no unexpected levitation, bottoming out, jitter, tipping or tunnelling.
4. Confirm 2-player seated ownership, deadman timeout and headlights.
5. Profile 4 raycasts/car/frame at target player counts and on mobile clients.

No CI/GitHub Actions; source-only changes.
