# Sprint 07 follow-up: profile mutation lane + guarded garage

## Delivered in source
- ProfileService.Mutate validates a candidate copy and writes via DataStore UpdateAsync before making it current.
- Get() mutable profile accessor replaced by Read() defensive decode.
- Concurrent in-server writes to a profile are gated; storage errors fail closed.
- Test garage writes the starter configuration only after persistence acknowledges it.
- Shared prototype car reserves tuning to one user at a time; reset to defaults when that user leaves.
- Unpublished local Studio retains explicit ephemeral test mode.

## Release blockers
- No dedicated personal vehicle instance or restoration from saved garage at spawn.
- Lease renewal uses UpdateAsync. Multi-server lease renewal, shutdown, throttling and corrupted-data behavior need real Roblox Studio validation.
- Client-visible changes to the shared prototype remain development-only. Two players must not interpret this as production ownership.
- No money, purchases, inventory, car-market transactions or Robux processing have been enabled.
- No actual execution of Luau or Roblox Studio from GitHub connector. No CI configured.

## Manual acceptance tests
1. Published staging experience: load profile and change prototype build; confirm persisted field in DataStore.
2. Force update failure; verify garage attributes remain unchanged.
3. Two players try modifying the shared prototype; secondary player is blocked.
4. Disconnect owner, verify prototype reset.
5. Reconnect: persisted build remains in profile but test car is intentionally not restored to it until personal spawner exists.
6. Concurrent session/lease tests and server shutdown; avoid production until lossless retry/recovery is established.
