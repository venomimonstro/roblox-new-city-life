--!strict
-- Conservative vehicle envelopes in studs/s and studs/s², not real SI units.
-- Different classes require separate handling laws; never reuse car road traction
-- for boats or aircraft. These are playable prototypes, not certified realism.
local Specs = {
    bicycle = {kind="cycle", mass=38, speed=38, acceleration=17, yaw=1.75, drag=0.055, lift=0, span=2},
    motorcycle = {kind="cycle", mass=180, speed=95, acceleration=49, yaw=2.05, drag=0.045, lift=0, span=2},
    dirtbike = {kind="cycle", mass=145, speed=72, acceleration=43, yaw=2.1, drag=0.07, lift=0, span=2},
    truck = {kind="road", mass=4200, speed=67, acceleration=26, yaw=0.85, drag=0.07, lift=0, span=4},
    tractor = {kind="road", mass=3200, speed=29, acceleration=16, yaw=0.95, drag=0.12, lift=0, span=4},
    bus = {kind="road", mass=6500, speed=65, acceleration=22, yaw=0.82, drag=0.09, lift=0, span=4},
    speedboat = {kind="water", mass=1300, speed=90, acceleration=32, yaw=1.1, drag=0.09, lift=1, span=0},
    fishingboat = {kind="water", mass=3700, speed=39, acceleration=15, yaw=0.65, drag=0.12, lift=1, span=0},
    propplane = {kind="air", mass=2100, speed=155, acceleration=35, yaw=0.85, drag=0.04, lift=1, span=3},
}
for _, spec in Specs do table.freeze(spec) end
return table.freeze(Specs)
