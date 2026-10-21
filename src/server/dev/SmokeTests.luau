--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Math = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleMath"))

local SmokeTests = {}

function SmokeTests.Run()
    assert(Math.StudsPerSecondToKmh(-1) == 0, "Negative speed clamps")
    assert(math.abs(Math.StudsPerSecondToKmh(100) - 100.8) < 0.001, "Unit conversion")
    assert(Math.DriveAcceleration(1, 100, 20, 10, 95, 20) == 0, "Forward speed limit")
    assert(Math.DriveAcceleration(-1, -30, 20, 10, 95, 20) == 0, "Reverse speed limit")
    assert(Math.DriveAcceleration(1, 0, 20, 10, 95, 20) == 20, "Acceleration")
    assert(Math.SteeringAngularSpeed(1, 0, 1.65) == 0, "No stationary turning")
    assert(Math.SteeringAngularSpeed(1, 25, 1.65) < 0, "Forward steering")
    assert(Math.SteeringAngularSpeed(1, -25, 1.65) > 0, "Reverse steering")
    assert(Math.TractionFactor(Enum.Material.Ice) < Math.TractionFactor(Enum.Material.Asphalt), "Ice must reduce traction")
    assert(Math.TractionFactor(Enum.Material.Sand) < Math.TractionFactor(Enum.Material.Grass), "Sand must reduce traction")
    assert(Math.TractionFactor(Enum.Material.Asphalt) == 1, "Normal road traction")
    print("[StreetCity] PASS: 11 deterministic math smoke checks")
end

return SmokeTests
