--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Math = require(Shared:WaitForChild("VehicleMath"))
local Powertrain = require(Shared:WaitForChild("Powertrain"))
local Catalog = require(Shared:WaitForChild("PartsCatalog"))
local RoadGraph = require(Shared:WaitForChild("RoadGraph"))
local VehicleBuild = require(Shared:WaitForChild("VehicleBuild"))
local Districts = require(Shared:WaitForChild("DistrictConfig"))
local ProfileSchema = require(Shared:WaitForChild("ProfileSchema"))
local MutationOutcome = require(Shared:WaitForChild("ProfileMutationOutcome"))
local ParkingLayout = require(Shared:WaitForChild("ParkingLayout"))
local Transactions = require(Shared:WaitForChild("GarageTransactions"))
local RaceValidation = require(Shared:WaitForChild("RaceValidation"))
local AssetValidator = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("ModelAssetValidator"))
local VehicleFactory = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("VehicleFactory"))

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
    local reserved: {[string]: boolean} = {}
    assert(ParkingLayout.Capacity == 48)
    for slot = 0, ParkingLayout.Capacity - 1 do
        local pos = ParkingLayout.Position(slot)
        assert(pos and math.abs(pos.Z) == 200 and math.abs(pos.X) <= 216)
        local key = tostring(pos.X) .. ":" .. tostring(pos.Z)
        assert(not reserved[key], "Parking slot overlap")
        reserved[key] = true
    end
    assert(ParkingLayout.Position(-1) == nil)
    assert(ParkingLayout.Position(48) == nil)
    assert(ParkingLayout.Position(1.5) == nil)
    assert(Math.ContactTraction(0) == 0)
    assert(Math.ContactTraction(4) == 1)
    assert(Math.ContactTraction(2) == 0.5)
    assert(Math.SpringAcceleration(0, 10, 380, 18) == 0)
    assert(Math.SpringAcceleration(0.5, 0, 380, 18) == 190)
    assert(Math.SpringAcceleration(1, -1000, 380, 18) > 0)
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
    local token = "server-token"
    assert(MutationOutcome.Classify(true, false, true, false, nil, token, false) == "rejected")
    assert(MutationOutcome.Classify(true, true, false, false, {
        owner = token, data = {},
    }, token, true) == "committed")
    assert(MutationOutcome.Classify(true, true, false, false, {
        owner = "different-server", data = {},
    }, token, true) == "uncertain")
    assert(MutationOutcome.Classify(false, false, true, false, nil, token, false) == "uncertain")
    assert(MutationOutcome.Classify(true, false, false, true, nil, token, false) == "uncertain")
    assert(MutationOutcome.Classify(true, false, false, false, nil, token, false) == "uncertain")
    local fresh = ProfileSchema.New()
    assert(fresh.schemaVersion == 3 and fresh.garage.starter ~= nil)
    local decoded = ProfileSchema.Decode(fresh)
    assert(decoded and decoded.credits == 0)
    fresh.credits = -1
    assert(ProfileSchema.Decode(fresh) == nil)
    local invalid = ProfileSchema.New()
    invalid.garage.starter.engineId = "invalid"
    assert(ProfileSchema.Decode(invalid) == nil)
    assert(ProfileSchema.Decode({schemaVersion = 999, credits = 0, garage = {}}) == nil)
    local priorV2 = ProfileSchema.New()
    priorV2.schemaVersion = 2
    priorV2.bankCredits = nil
    priorV2.stolenGoods = nil
    priorV2.nutrition = nil
    priorV2.fitness = nil
    priorV2.bodyFat = nil
    local upgraded = ProfileSchema.Decode(priorV2)
    assert(upgraded and upgraded.schemaVersion == 3 and upgraded.credits == 0
        and upgraded.bankCredits == 0 and upgraded.stolenGoods == 0
        and upgraded.fitness == 15, "V2 to V3 migration must preserve wallet and cars")
    local legacy = ProfileSchema.Decode({
        schemaVersion = 1, credits = 1200,
        garage = {starter = {engineId = "stock_i4", gearboxId = "street_5", tireId = "street"}},
    })
    assert(legacy and legacy.schemaVersion == 3 and legacy.selectedVehicleId == "starter")
    local wallet = ProfileSchema.New()
    assert(Transactions.AwardCredits(wallet, 2000, "race_test_00001"))
    assert(not Transactions.AwardCredits(wallet, 2000, "race_test_00001"))
    assert(wallet.credits == 2000)
    assert(Transactions.PurchasePart(wallet, "tire_sport_new", "part_test_00001"))
    assert(wallet.credits == 1100 and wallet.inventory.tire_sport_new == 1)
    assert(not Transactions.PurchasePart(wallet, "tire_sport_new", "part_test_00001"))
    assert(Transactions.InstallPart(wallet, "starter", "tire_sport_new", "install_test_00001"))
    assert(wallet.garage.starter.tireId == "sport")
    assert(wallet.inventory.tire_sport_new == nil)
    assert(not Transactions.InstallPart(wallet, "starter", "tire_sport_new", "install_test_00002"))
    assert(ProfileSchema.Decode(wallet) ~= nil)
    wallet.credits = 25000
    assert(Transactions.PurchaseVehicle(wallet, "street_coupe", "car_test_00001", "car_buy_00001"))
    assert(wallet.credits == 13000)
    assert(not Transactions.PurchaseVehicle(wallet, "street_coupe", "car_test_00001", "car_buy_00001"))
    assert(Transactions.SelectVehicle(wallet, "car_test_00001"))
    assert(ProfileSchema.Decode(wallet) ~= nil)
    local badInventory = ProfileSchema.New()
    badInventory.inventory.unknown_sku = 1
    assert(ProfileSchema.Decode(badInventory) == nil)
    local badJournal = ProfileSchema.New()
    badJournal.recentOperations[3] = "sparse_test_0001"
    assert(ProfileSchema.Decode(badJournal) == nil, "Reject sparse operation journal")
    local mapJournal = ProfileSchema.New()
    mapJournal.recentOperations.bad = "invalid_journal"
    assert(ProfileSchema.Decode(mapJournal) == nil, "Reject operation dictionary")
    assert(RaceValidation.PositionPlausible(Vector3.zero, Vector3.new(0, 0, 90), 1, 100))
    assert(not RaceValidation.PositionPlausible(Vector3.zero, Vector3.new(0, 0, 500), 1, 100))
    assert(RaceValidation.CheckpointReached(Vector3.new(4, 0, 0), Vector3.zero, 5))
    assert(not RaceValidation.CheckpointReached(Vector3.new(10, 0, 0), Vector3.zero, 5))
    assert(RaceValidation.SegmentTimePlausible(Vector3.zero, Vector3.new(100, 0, 0), 1, 100))
    assert(not RaceValidation.SegmentTimePlausible(Vector3.zero, Vector3.new(100, 0, 0), 0.1, 100))
    local noCredit = ProfileSchema.New()
    assert(not Transactions.PurchasePart(noCredit, "engine_sport_new", "unpaid_part_0001"))
    assert(noCredit.credits == 0 and noCredit.inventory.engine_sport_new == nil)
    assert(not Transactions.PurchaseVehicle(noCredit, "street_coupe", "car_unpaid_0001", "unpaid_car_0001"))
    assert(noCredit.credits == 0 and noCredit.garage.car_unpaid_0001 == nil)
    local safeModel = Instance.new("Model")
    local safePart = Instance.new("Part")
    safePart.Size = Vector3.new(5, 2, 9)
    safePart.Parent = safeModel
    assert(AssetValidator.Validate(safeModel).ok)
    local executable = Instance.new("Script")
    executable.Parent = safeModel
    assert(not AssetValidator.Validate(safeModel).ok)
    executable:Destroy()
    local unwantedSeat = Instance.new("VehicleSeat")
    unwantedSeat.Parent = safeModel
    assert(not AssetValidator.Validate(safeModel).ok, "Imported seat must be denied")
    unwantedSeat:Destroy()
    local unwantedRemote = Instance.new("RemoteEvent")
    unwantedRemote.Parent = safeModel
    assert(not AssetValidator.Validate(safeModel).ok, "Imported remote must be denied")
    unwantedRemote:Destroy()
    safePart.Size = Vector3.new(60, 2, 9)
    assert(not AssetValidator.Validate(safeModel).ok)
    safeModel:Destroy()
    -- Real Factory geometry assertion: spawn orientation matches east-west roads.
    local parkingFixture = Instance.new("Folder")
    parkingFixture.Name = "SmokeVehicleFactory"
    parkingFixture.Parent = workspace
    local car = VehicleFactory.Create(parkingFixture, Vector3.new(0, 1000, 0), math.pi / 2)
    assert(car.Model:GetAttribute("StreetCityVehicle") == true, "Factory vehicle tag")
    assert(math.abs(car.Chassis.CFrame.LookVector.X) > 0.98,
        "Personal car must face along the east-west road")
    assert(math.abs(car.Chassis.CFrame.LookVector.Z) < 0.1,
        "Vehicle spawn must not face into pavement / buildings")
    assert(VehicleFactory.ApplyCatalog(car, "street_coupe"), "Owned coupe appearance")
    assert(car.Model:GetAttribute("VehicleCatalogId") == "street_coupe",
        "Factory catalog identity must be visible")
    local coupeHood = car.Model:FindFirstChild("Hood")
    assert(coupeHood and coupeHood:IsA("BasePart")
        and coupeHood.Color == Color3.fromRGB(205, 53, 63),
        "Bought coupe appearance must differ from starter")
    assert(VehicleFactory.ApplyCatalog(car, "starter_hatch"), "Starter appearance")
    assert(coupeHood.Color ~= Color3.fromRGB(205, 53, 63),
        "Switching car must update prototype visuals")
    assert(not VehicleFactory.ApplyCatalog(car, "unknown_car"),
        "Unlisted car appearance must fail")
    parkingFixture:Destroy()
    local world = workspace:FindFirstChild("StreetCityPrototypeWorld")
    assert(world and world:FindFirstChild("DistrictBlockouts"), "Missing generated districts")
    -- Prevent real collisions between procedural building lots and the street grid.
    local legacyBuildings = world:FindFirstChild("Buildings")
    assert(legacyBuildings and #legacyBuildings:GetChildren() == 0,
        "Duplicate downtown building generator is still producing overlapping geometry")
    local districtRoot = world:FindFirstChild("DistrictBlockouts")
    for _, district in Districts do
        local zone = districtRoot:FindFirstChild(district.id)
        assert(zone, "Missing district zone " .. district.id)
        for _, part in zone:GetChildren() do
            if part:IsA("BasePart") and string.sub(part.Name, 1, 9) == "Building_" then
                local distX = math.abs(part.Position.X
                    - math.round(part.Position.X / 100) * 100)
                local distZ = math.abs(part.Position.Z
                    - math.round(part.Position.Z / 100) * 100)
                assert(distX >= part.Size.X / 2 + 12.5,
                    "District building overlaps a vertical road: " .. district.id)
                assert(distZ >= part.Size.Z / 2 + 12.5,
                    "District building overlaps a horizontal road: " .. district.id)
            end
        end
    end
    assert(world:FindFirstChild("PlayerSpawn"), "Missing player spawn")
    local ocean = world:FindFirstChild("Ocean")
    assert(ocean and ocean:IsA("BasePart") and not ocean.CanQuery,
        "Ocean decoration must not affect suspension raycasts")
    local raceStart = world:FindFirstChild("TimeTrialStart")
    assert(raceStart and raceStart:IsA("BasePart") and not raceStart.CanQuery,
        "Race marker must not affect suspension raycasts")
    for i = 1, 6 do
        local checkpoint = world:FindFirstChild("CircuitCheckpoint_" .. i)
        assert(checkpoint and checkpoint:IsA("BasePart") and not checkpoint.CanQuery,
            "Noncollidable checkpoint must not be a suspension contact")
    end
    local terminal = world:FindFirstChild("PersonalGarageTerminal")
    assert(terminal and terminal:IsA("BasePart"), "Missing personal garage terminal")
    assert(not terminal.CanCollide and not terminal.CanQuery,
        "Garage terminal must not obstruct the race road")
    local shopCount = 0
    for _, part in world:GetChildren() do
        if part.Name:sub(1, 5) == "Shop_" then
            shopCount += 1
            assert(part:IsA("BasePart") and not part.CanCollide and not part.CanQuery,
                "Shop stand must not obstruct driving or suspension")
        end
    end
    assert(shopCount >= 12, "Expected five part stands, five installs, and two car dealers")
    assert(world:FindFirstChild("Shop_Buy Sport Sedan: 24000 cr"),
        "Catalogued sport sedan must have a real purchase interaction")
    for _, offerId in {"tire_worn_used", "tire_sport_new", "gearbox_sport_new",
        "engine_sport_new", "engine_v6_used"} do
        local install = world:FindFirstChild("Shop_Install " .. offerId)
        assert(install and install:FindFirstChildOfClass("ProximityPrompt"),
            "Missing explicit item installation stand: " .. offerId)
    end
    local locator = world:FindFirstChild("FindMyCarTerminal")
    assert(locator and locator:IsA("BasePart")
        and locator:FindFirstChildOfClass("ProximityPrompt"),
        "New player cannot locate their personal car")
    assert(not locator.CanCollide and not locator.CanQuery, "Car locator blocks physics")
    if game:GetService("RunService"):IsStudio() and game.GameId == 0 then
        assert(world:FindFirstChild("Shop_DEV sandbox +25000 credits"),
            "Unpublished Studio must allow quick economy test without racing 20 times")
    end
    local remotes = Shared.Parent:FindFirstChild("StreetCityRemotes")
    assert(remotes and remotes:FindFirstChild("GarageNotice"), "Missing shop notification event")
    assert(remotes:FindFirstChild("VehicleInput"), "Missing driving input event")
    assert(remotes:FindFirstChild("ToggleHeadlights"), "Missing headlight event")
    assert(workspace:FindFirstChild("ActiveVehicles"), "Missing vehicle container")
    print("[StreetCity] PASS: domain smoke assertions incl race, economy, asset import and migration")
end
return SmokeTests
