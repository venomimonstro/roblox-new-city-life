# Sprint 03 integration — source-only receipt

Added engine RPM and gear state to the prototype vehicle. Positive-throttle acceleration is now modulated by a bounded wheel-force factor derived from a catalog powertrain. Negative throttle retains the older braking/reverse model.

This **is not** a production car physics system. The car uses a single arcade chassis without independent suspension, articulated wheels or clutch simulation. Its actual mass/units are not yet calibrated to a road test.

## Mandatory Studio acceptance before declaring complete
- Verify throttle/steering values arrive on server in a 2-client session.
- Test forward/reverse braking from rest and at speed.
- Verify gear state progresses and RPM remains within declared limits.
- Measure 0–100 km/h repeatability and compare changes between catalog configurations only after vehicle tuning is wired.
- Verify sleep/disconnect while seated, no stale acceleration or ownership bugs.
- Confirm keyboard and mobile controls under latency.
