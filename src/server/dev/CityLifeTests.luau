--!strict
-- Source-connected Studio acceptance for first city-life vertical slice.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("HomeLayout"))
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Vehicles = require(Shared:WaitForChild("VehicleCatalog"))
local Tests = {}

function Tests.Run()
    assert(Layout.Capacity == 48, "Residential capacity changed without release plan")
    local positions = {}
    for slot = 0, Layout.Capacity - 1 do
        local plot = Layout.Plot(slot)
        assert(plot and plot.car and plot.house and plot.respawn)
        assert(math.abs(plot.car.Z) == 226 and math.abs(plot.house.Z) == 258)
        assert(math.abs(plot.respawn.Z) == 245)
        local key = tostring(plot.car.X) .. ":" .. tostring(plot.car.Z)
        assert(not positions[key], "Two cars share one private garage")
        positions[key] = true
        assert(plot.heading == (if slot < 24 then math.pi else 0),
            "Garage exit must face its closest street")
        assert((plot.house - plot.car).Magnitude >= 30, "House and parking collide")
    end
    assert(Layout.Plot(-1) == nil and Layout.Plot(48) == nil)
    assert(Layout.Preferred(48) == 0 and Layout.Preferred(49) == 1)
    assert(Layout.Preferred(-1) == 47 and Layout.Preferred(-2) == 46,
        "Studio simulated users must receive independent home plots")

    local catalogIds = {}
    for id = 1, 3 do
        local profile = Schema.New(id)
        local car = profile.garage.starter
        assert(Vehicles[car.catalogId] and Vehicles[car.catalogId].price == 0)
        assert(car.engineId == "stock_i4"
            and car.gearboxId == "street_5" and car.tireId == "street",
            "Starting vehicle advantage is forbidden")
        assert(not catalogIds[car.catalogId], "All new players got same starter")
        catalogIds[car.catalogId] = true
        assert(Schema.Decode(profile) ~= nil, "New personalized profile invalid")
    end
    assert(Schema.Decode(Schema.New()) ~= nil, "Old sandbox profile migration broken")

    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local homes = world:FindFirstChild("ResidentialHomes")
    assert(homes and #homes:GetChildren() == 48, "Incomplete residential world")
    for index = 1, 48 do
        local house = homes:FindFirstChild("Home_" .. index)
        local sign = house and house:FindFirstChild("GarageTerminal")
        assert(sign and sign:FindFirstChild("GaragePrompt"), "Unusable home garage")
    end
    local citizens = world:FindFirstChild("CityPedestrians")
    assert(citizens and #citizens:GetChildren() == 28,
        "Need four active residents in each of seven districts")
    local jobs = world:FindFirstChild("CityJobs")
    assert(jobs and jobs:FindFirstChild("Fish_Cast")
        and jobs:FindFirstChild("Fish_Catch") and jobs:FindFirstChild("Fish_Sell"))
    for _, id in {"taxi", "firefighter", "police", "cleaner", "office"} do
        assert(jobs:FindFirstChild("JobStart_" .. id)
            and jobs:FindFirstChild("JobFinish_" .. id),
            "Incomplete shift loop for " .. id)
    end
    local vehicles = workspace:FindFirstChild("ActiveVehicles")
    local ambient = 0
    local police = 0
    if vehicles then
        for _, model in vehicles:GetChildren() do
            if model:GetAttribute("TrafficNPC") == true then
                ambient += 1
                if model:GetAttribute("IsPolice") == true then police += 1 end
            end
        end
    end
    assert(ambient >= 6 and police >= 1, "Street traffic or police failed")
    assert(Shared.Parent:FindFirstChild("StreetCityWantedState"),
        "Wanted star event not installed")
    print("[StreetCity] PASS: residential, starter-car, job, pedestrian and traffic smoke tests")
end

return Tests
