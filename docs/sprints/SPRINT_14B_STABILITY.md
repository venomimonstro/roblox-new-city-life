# Sprint 14B — vehicle suspension stability and imported-model regression

Implemented in source:
- Four-contact suspension lift capped at 1.15 times workspace gravitational acceleration, replacing fixed high vertical acceleration.
- Raycasts ignore water so the car cannot treat the ocean surface as driveable road.
- Studio smoke suite includes a valid car-like Model, rejection of embedded Lua Script, and oversized part rejection.

Release blockers:
- This is a center-of-mass arcade suspension, not articulated corner-specific wheel physics. Spring constants and ride height are NOT calibrated by playtesting.
- A static assertion suite cannot prove physics stability.
- No Roblox Studio / Luau compilation or Rojo build executed in this environment.
- Need 2-client tests, flat asphalt/sand transition, curbs, hills, airborne behavior, high-latency client and Android performance.
- Test Cube 4D-produced assets manually, inspect textures/mesh collision budgets and avoid trusting automatic validation alone.

Keep CI/GitHub Actions absent; do not publish as production-ready.
