--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Math = require(Shared:WaitForChild("VehicleMath"))
local Powertrain = require(Shared:WaitForChild("Powertrain"))
local Catalog = require(Shared:WaitForChild("PartsCatalog"))
local RoadGraph = require(Shared:WaitForChild("RoadGraph"))
local VehicleBuild = require(Shared:WaitForChild("VehicleBuild"))
local Districts = require(Shared:WaitForChild("DistrictConfig"))

local SmokeTests = {}
function SmokeTests.Run()
    assert(Math.StudsPerSecondToKmh(-1) == 0)
    assert(math.abs(Math.StudsPerSecondToKmh(100) - 100.8) < 0.001)
    assert(Math.DriveAcceleration(1, 100, 20, 10, 95, 20) == 0)
    assert(Math.DriveAcceleration(-1, -30, 20, 10, 95, 20) == 0)
    assert(Math.DriveAcceleration(1, 0, 20, 10, 95, 20) == 20)
    assert(Math.SteeringAngularSpeed(1, 0, 1.65) == 0)
    assert(Math.SteeringAngularSpeed(1, 25, 1.65) < 0)
    assert(Math.SteeringAngularSpeed(1, -25, 1.65) > 0)
    assert(Math.TractionFactor(Enum.Material.Ice) < Math.TractionFactor(Enum.Material.Asphalt))
    assert(Math.TractionFactor(Enum.Material.Sand) < Math.TractionFactor(Enum.Material.Grass))
    assert(Math.TractionFactor(Enum.Material.Asphalt) == 1)
    local stock = Catalog.CreateSpec("stock_i4", "street_5", "street")
    local sport = Catalog.CreateSpec("sport_i4", "sport_6", "sport")
    assert(stock and sport and Powertrain.Validate(stock) and Powertrain.Validate(sport))
    assert(Powertrain.Torque(sport, sport.peakRpm) > Powertrain.Torque(stock, stock.peakRpm))
    assert(Powertrain.EngineRpm(stock, 1, 0) == stock.idleRpm)
    assert(Powertrain.WheelForce(stock, 4000, 1) > Powertrain.WheelForce(stock, 4000, 5))
    assert(Powertrain.Shift(stock, {gear = 1, rpm = stock.redlineRpm}, 1) == 2)
    assert(Powertrain.Shift(stock, {gear = 3, rpm = 1100}, 0.2) == 2)
    assert(Catalog.CreateSpec("unknown", "street_5", "street") == nil)
    local graph = RoadGraph.Grid(2, 100)
    assert(RoadGraph.Connected(graph, "0:0"))
    assert(#graph["0:0"].neighbors == 4)
    assert(#Districts == 7, "Seven zones")
    local ids = {}
    for _, zone in Districts do
        assert(not ids[zone.id], "Unique zone ids")
        ids[zone.id] = true
    end
    assert(VehicleBuild.Resolve({engineId = "stock_i4", gearboxId = "street_5", tireId = "street"}) ~= nil)
    assert(VehicleBuild.Resolve({engineId = "unknown", gearboxId = "street_5", tireId = "street"}) == nil)
    assert(VehicleBuild.Resolve({engineId = "stock_i4", gearboxId = "street_5", tireId = "street", finalDrive = 0}) == nil)
    assert(VehicleBuild.Resolve({engineId = "stock_i4", gearboxId = "street_5", tireId = "street", finalDrive = 4.2}) ~= nil)
    print("[StreetCity] PASS: baseline, district and tuning smoke assertions")
end
return SmokeTests
