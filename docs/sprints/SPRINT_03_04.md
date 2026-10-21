# Sprints 03–04 — modular driveline math, catalog, connected road graph

## Implemented in source
- Pure powertrain math: basic torque curve, wheel-force calculation, RPM from ground speed, automatic shift thresholds and validation.
- Data catalogs: three engines, two transmissions, three tire types, including a worn tire configuration.
- Deterministic, connected road graph with explicit neighbors. This graph is a future traffic/routing foundation, not an NPC implementation.
- Expanded Studio startup assertions from 11 to 20.

## Quality gates / limitations
- Torque curve is a **gameplay approximation**, not a professional vehicle simulator.
- Drivetrain does **not yet actuate the chassis** and cannot be represented as live tuning.
- No vehicle UI, garage purchase, persistent tuning or inventory.
- Grid generation is data-only; it is not seven rendered districts.
- Luau compilation and Roblox Studio gameplay tests not executed by GitHub connector.
- Before integrating the driveline into driving physics, verify unit conversion (studs/seconds to m/s), time-step stability and acceleration bounds on a dual-client test session.

## Next
Integrate RPM/gear and safe configs with live chassis, then create player-facing garage/tuning only after repeatable handling tests.
