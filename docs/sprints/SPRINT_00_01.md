# Sprint 00 and initial Sprint 01/02 — implementation receipt

## Delivered in \`main\`
- Rojo data model mapping; source split by server/client/shared.
- Repeatable simple blockout map from explicit seed: 5×5 roads, 16 buildings, coast and hill silhouette.
- One physics-driven test coupe built out of Roblox primitives with client-visible speed HUD, driver-seat prompt and headlights.
- Server-side rate-limited headlight toggle only for seated driver.
- Shared pure \`VehicleMath\` with eight assertions triggered during Studio server boot.
- Documentation and local structure check, no GitHub Actions.

## Not implemented
Production-grade automotive simulation, articulated suspension, gear ratios, user profiles, seven polished districts, Cube 4D 3D generation, saved cars, shops, NPC traffic/racing, paid products, production deployment.

## Remaining to close the sprint
1. Local \`rojo build\` and Studio Rojo synchronization.
2. Confirm VehicleSeat values actually reach the authoritative server, test on keyboard/touch.
3. Check driving physics on slopes, acceleration, yaw/roll stability and ground contact.
4. Playtest with two clients (seat ownership, headlight authorization, replication).
5. Address measured stability/performance bugs; only then mark sprint Accepted.

## Next implementation priority
Replace the provisional force + cosmetic-wheel prototype with an independently testable universal chassis/handling module and explicit multiplayer motion validation. Do not generate the full city before this gate is passed.
