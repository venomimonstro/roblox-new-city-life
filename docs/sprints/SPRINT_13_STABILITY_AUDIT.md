# Sprint 13 — source-level stability and transaction audit

## Fixed
- ProfileService.Mutate previously reported success if UpdateAsync returned an existing owned record while the edit callback rejected the operation. The result now includes a confirmation that the final transformation accepted the edit.
- Race checkpoints were reordered so the course follows the existing street grid rather than asking the driver to cut diagonally through buildings.

## Still mandatory before release
1. Run Luau type checker and Rojo build, then open the result in Roblox Studio.
2. In Studio sandbox, attempt insufficient-credit purchase, repeated inventory transaction, installing a part already equipped, and second car purchase. All invalid cases must return failure with no balance change.
3. In staging DataStore, simulate rejected UpdateAsync mutation and ambiguous timeout; check no duplicate inventory or credits and no misleading success message.
4. Start a solo race; drive each numbered waypoint in sequence, test off-route and teleport attempts.
5. Two-player ownership, driving synchronization, remote spam, disconnects and 15-minute physics stability.
6. Never switch production on until DataStore conflict/lease and mobile performance are validated.

GitHub commits are evidence of source changes only, not runtime acceptance. No CI/GitHub Actions.
