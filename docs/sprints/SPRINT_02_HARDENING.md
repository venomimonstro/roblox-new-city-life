# Sprint 02 — network and driving stability hardening

## Implemented in source
- Server-retained network ownership for provisional test vehicle (prevents arbitrary client-authoritative physics state).
- Seat occupant changes update a driver identifier for diagnostics; no trust in a client-provided user ID.
- Improved proximity prompt requires the humanoid to be alive and near the car.
- Surface traction multiplier distinguishes ice, sand, grass and road, with bounded coefficient.
- All three new math checks run in Roblox Studio; total 11.
- Headlight request remains seat-authorized and rate limited.

## Limitations and risks
- This is still a basic arcade chassis, not four-wheel constraints with genuine suspension/transmission physics.
- Server-ownership might feel sluggish on high latency connections; must measure in Roblox Studio before switching to client ownership.
- VehicleSeat throttle/steer replication must be verified in Studio dual-client test. No claim of live gameplay verification.
- Surface raycast tests one contact point; next sprint must add wheel contact points, spring/damping, and stable chassis orientation.

## Manual acceptance
- [ ] Two-player Studio test: both players see the same movement, driver-only light toggle.
- [ ] Enter/leave/rejoin the vehicle, verify neutral throttle after exiting.
- [ ] Drive from asphalt to grass and sand, check perceptible traction change.
- [ ] Test steep road, jump, overturned car and server reset.
- [ ] Check mobile steering and network latency.
- [ ] Observe output: 11 deterministic math assertions pass.

Next: engine torque / transmission / four-wheel suspension tests, only after gate above.
