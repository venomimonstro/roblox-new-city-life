# Sprints 05 and 08 (partial implementation) — source receipt

## Sprint 05
Seven named deterministic district blockouts with small bounded part counts. Connector roads are schematic orthogonal roads. Existing downtown and test car remain. Not final terrain, scenic art, collision-polished roadways, or streaming-tested landscape.

## Sprint 08 — domain foundation
VehicleBuild.Resolve accepts only catalog-backed engine/gearbox/tire identifiers. Optional final drive must be finite and in 2.5..5.5. Returns a validated frozen powertrain specification; unknown IDs or out-of-range ratios fail closed. This is *not* yet an interactive garage or a purchasing system.

## Remaining acceptance
- Rojo build and Studio compilation.
- Two-player test, driving between all seven areas.
- Device memory and FPS on a low-end phone.
- Physically driven tuning applied to a spawned car.
- Gearbox/torque changes under acceleration logged and compared.
- Ensure no client can apply arbitrary part parameters.

Source commits are not evidence of passed runtime tests. No CI or GitHub Actions.
