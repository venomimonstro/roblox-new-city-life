--!strict
-- Studio checks for damage thresholds, crash-abuse, and rescue safety.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Damage = require(Shared:WaitForChild("VehicleDamageRules"))
local Tests = {}
function Tests.Run()
    local cases = {
        {5, 12, true, 0}, -- kerb / parking
        {14, 40, true, 0}, -- cosmetic hit below limit
        {30, 50, true, 11}, -- collision
        {90, 110, true, 55}, -- high-speed crash
        {150, 165, true, 85}, -- capped damage
        {160, 165, false, 0}, -- no damage while falling
    }
    for _, case in cases do
        local event = Damage.Impact(case[1], case[2], case[3], true)
        assert(event.damage == case[4], "Unexpected impact severity")
        assert(event.occupantDamage >= 0 and event.occupantDamage <= 35)
    end
    assert(Damage.Impact(0/0, 80, true, true).damage == 0, "NaN cannot cause damage")
    assert(Damage.Impact(9e30, 9e30, true, true).damage == 0,
        "Overflow physics must fail closed")
    assert(Damage.DriveFactor(100) > Damage.DriveFactor(25))
    assert(Damage.DriveFactor(0) == 0, "Wrecked vehicle cannot accelerate")
    assert(Damage.Status(0) == "wrecked")
    assert(Damage.Status(50) == "damaged")
    assert(Damage.Status(100) == "operational")
    print("[StreetCity] PASS: 6 impact classes and physics edge cases")
end
return Tests
