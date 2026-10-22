--!strict
-- Actual Roblox Studio integration assertions for the new transport fleet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Specs = require(ReplicatedStorage.Shared:WaitForChild("TransportSpecs"))
local Tests = {}

function Tests.Run()
    local counts = {road=0,cycle=0,water=0,air=0}
    local total = 0
    for name, spec in Specs do
        total += 1
        assert(type(name) == "string" and #name > 2)
        assert(counts[spec.kind] ~= nil, "Transport category is unknown")
        counts[spec.kind] += 1
        assert(spec.speed >= 15 and spec.speed <= 180
            and spec.acceleration > 0 and spec.acceleration < 80
            and spec.mass > 15 and spec.mass < 10000
            and spec.yaw > 0 and spec.yaw <= 3
            and spec.drag > 0 and spec.drag < 1,
            "Transport envelope outside safe initial physics bounds")
    end
    assert(total >= 9 and counts.road >= 3 and counts.cycle >= 3
        and counts.water >= 2 and counts.air >= 1,
        "Missing vehicle modes from the requested transport families")
    local folder = workspace:FindFirstChild("StreetCityTransport")
    assert(folder and folder:IsA("Folder"), "Specialized fleet was not spawned")
    local actual = {}
    for _, model in folder:GetChildren() do
        if model:IsA("Model") then
            local typeId = model:GetAttribute("TransportType")
            local spec = type(typeId) == "string" and Specs[typeId] or nil
            assert(spec, "Fleet vehicle has no validated type")
            assert(model:GetAttribute("TransportKind") == spec.kind,
                "Wrong controller class for " .. typeId)
            assert(model.PrimaryPart and model.PrimaryPart:IsA("BasePart")
                and not model.PrimaryPart.Anchored, "Vehicle cannot move physically")
            local seat = model:FindFirstChild("DriverSeat")
            assert(seat and seat:IsA("VehicleSeat"),
                "Transport must have a working driver seat")
            local f = model.PrimaryPart:FindFirstChild("DriveForce")
            local lift = model.PrimaryPart:FindFirstChild("SuspensionForce")
            local yaw = model.PrimaryPart:FindFirstChild("YawMotor")
            assert(f and f:IsA("VectorForce")
                and lift and lift:IsA("VectorForce")
                and yaw and yaw:IsA("AngularVelocity"),
                "Missing force actuators for " .. typeId)
            actual[typeId] = true
        end
    end
    for typeId in Specs do assert(actual[typeId], "Missing spawn " .. typeId) end
    local events = ReplicatedStorage:WaitForChild("StreetCityRemotes")
    assert(events:FindFirstChild("TransportInput")
        and events.TransportInput:IsA("RemoteEvent"),
        "No secure transport input channel")
    print("[StreetCity] PASS specialized physics fleet configuration: " .. total)
end

return Tests
