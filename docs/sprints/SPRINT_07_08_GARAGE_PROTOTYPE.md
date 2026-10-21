# Sprints 07–08 — test garage and tunable live chassis (partial)

## Implemented in source
- A test garage station in the starter map with proximity prompt.
- Three pre-approved configurations: Street, Sport and Used parts.
- Only server-side validated catalog IDs are applied. Caller must be alive, physically nearby, car empty and nearly stopped.
- Engine, gearbox and tire attributes now feed the car's driving loop. Tire class affects lateral grip; engine and gearbox affect bounded forward acceleration.
- Gear/RPM state resets when parts configuration changes.

## Not implemented or verified
- No owned garages, purchases, inventory, persistence, player-to-player trade or production-safe car spawning.
- No precise tire-force simulation, independent suspension, chassis calibration or reliable multiplayer test evidence.
- Roblox Studio build/typecheck/device testing has **not** been executed. No claims of commercial readiness.

## Manual acceptance
1. Start Studio with two clients. Confirm garage stand spawns beside the starter car.
2. Leave vehicle, walk to stand, activate prompt; observe BuildName changes.
3. Try switching with driver seated, with vehicle moving, while dead and at an excessive distance: all must fail.
4. Drive street, sport and worn-tire configurations on the same road, compare measured results.
5. Check Output for errors and confirm no duplicate garage stations.
6. Verify touch/keyboard prompts and 10-minute driving stability.

Do not expand public gameplay scope until these conditions pass.
