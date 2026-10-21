# Sprint 13B — stabilization of profile and vehicle ownership

Implemented in `main`:

- After an ambiguous or unsuccessful DataStore mutation response, the profile is invalidated when ownership of the returned record cannot be proven; the player is disconnected instead of receiving further write access.
- A rejected business operation (e.g. insufficient funds) returns failure and refreshes the cached server snapshot, without presenting a successful purchase.
- A vehicle with `OwnerUserId` rechecks its current seat occupant every server physics update. A forced seat assignment by another server script cannot authorize propulsion for a non-owner.

**Manual testing still required:**
- Roblox Studio single player and 2-client: throttle, steering, unauthorized `Seat:Sit`, driver exit, ownership changes and headlights.
- Published staging: UpdateAsync rejection, session lease conflict, profile service outage and reconnect.
- Verify no false success messages or duplicate credits/purchases.
- Rojo build, Luau type diagnostics and performance profiling; no CI is configured.

This is a code hardening patch, not evidence of completed runtime or penetration testing.
