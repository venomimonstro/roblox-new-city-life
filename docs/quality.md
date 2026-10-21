# Quality and verification gates

## Automated checks (local, no CI)
1. \`python3 tools/validate_project.py\`: checks Rojo project file, mandatory source paths and prohibition of workflow files.
2. In Roblox Studio, server boot executes \`SmokeTests.Run()\` **only when RunService:IsStudio()** and checks drivetrain calculations, profile migration, economic transactions, and race plausibility assertions. A test failure stops boot and is visible in Output.
3. \`rojo build default.project.json -o StreetCity.rbxlx\` should produce a standalone place. This build has NOT been executed in this environment.
4. Optional developer workstation checks: \`stylua --check src\`, \`selene src\`, then inspect Luau type diagnostics in Studio.

## Manual smoke test — Sprint 01/02
- [ ] Open a blank place (remove stock Baseplate/SpawnLocation first) and connect Rojo.
- [ ] Spawn appears on the provided green pad; map is generated once.
- [ ] Walk to the red/charcoal test coupe and press E to sit.
- [ ] Drive on roads with keyboard; confirm **server** gets input and moving car replicates to second player.
- [ ] Steering direction makes sense in both forward and reverse.
- [ ] Switch headlights with L and touch action while driving; spectator cannot toggle them.
- [ ] Leave seat / disconnect. Car does not produce uncontrolled motion or increasing force.
- [ ] Respawn and re-enter without another client losing input.
- [ ] Two-player collision/seat ownership and 10-minute play sessions without errors.
- [ ] Android device: legible speed HUD, touch action, no rendering freeze.
- [ ] Measure frame time and memory before building a larger world.

## Deferred gates before real players
- Profile loss, reconnect and simultaneous session test.
- Purchase retries, double awards, refund/recovery.
- NPC density and network congestion, streaming at speed.
- Mobile performance and stability.
- Abuse of all RemoteEvents.
- Separate Staging experience, signed off release/rollback.

## New closed-loop test
- [ ] Run unpublished Studio: personal car spawns with an **ephemeral** account profile.
- [ ] Drive through the six numbered time-trial checkpoints; server awards 650 credits after a plausible finish.
- [ ] Buy a used or new part, confirm credits decrease and inventory is updated.
- [ ] Exit car, install the part, verify personal car refreshes and tuning changes.
- [ ] Repeat same operation ID in pure test; balance/inventory must not change twice.
- [ ] Buy a second car after sufficient legitimate credits, switch at personal garage.
- [ ] In a published **staging** place: verify V1->V2 profile migration, safe conflict handling, and restore selected personal car.
- [ ] Disconnect driving client; ensure car stops accelerating after input timeout.
- [ ] Validate all network remotes against spam, invalid number types, NaN, infinite values and non-driver input.

**Current evidence:** all listed files exist in GitHub and source smoke assertions are authored. The Roblox Studio runtime, Rojo build, real device FPS and server load tests remain **unverified**. No public deployment or Robux purchase processing.
