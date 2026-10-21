--!strict
-- Pure deterministic gameplay simulation. Runs in Studio; does not contact DataStore
-- or create paid requests. Uses production Luau domain modules, NOT reimplementations.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Rules = require(Shared:WaitForChild("GarageTransactions"))
local Outcome = require(Shared:WaitForChild("ProfileMutationOutcome"))
local Course = require(Shared:WaitForChild("RaceCourse"))
local Race = require(Shared:WaitForChild("RaceValidation"))
local Parking = require(Shared:WaitForChild("ParkingLayout"))
local Sim = {}

local function fakeCommit(storage: any, serverToken: string, edit: (any) -> boolean)
    if storage.owner ~= serverToken then return false, nil end
    local copy = Schema.Decode(storage.data)
    if not copy or edit(copy) ~= true or not Schema.Decode(copy) then
        return false, nil
    end
    storage.data = Schema.Decode(copy)
    return true, storage.data
end

function Sim.Run()
    local assertions = 0
    local function check(value: boolean, reason: string)
        assert(value, "[ScenarioSimulation] " .. reason)
        assertions += 1
    end

    -- Complete driving/race reward -> shop -> install -> save -> rejoin.
    local accountA = Schema.New()
    local accountB = Schema.New()
    check(accountA.credits == 0 and accountB.credits == 0, "fresh accounts independent")
    check(not Rules.PurchasePart(accountA, "tire_sport_new", "unfunded_part_0001"),
        "unfunded purchase rejected")
    check(accountA.credits == 0 and next(accountA.inventory) == nil, "rejected purchase unchanged")

    local prior = Course.Start
    check((prior - Course.Points[1]).Magnitude >
        Course.StartRadius + Course.CheckpointRadius, "start and first checkpoint separated")
    for index, point in Course.Points do
        local distance = (point - prior).Magnitude
        check(distance > 2 * Course.CheckpointRadius, "adjacent checkpoints do not overlap " .. index)
        local elapsed = distance / 40 -- simulated travel at 40 studs/s
        check(Race.PositionPlausible(prior, point, elapsed, Course.MaxSpeed),
            "leg position plausible " .. index)
        check(Race.SegmentTimePlausible(prior, point, elapsed, Course.MaxSpeed,
            Course.CheckpointRadius), "leg time plausible " .. index)
        prior = point
    end
    check(not Race.CheckpointReached(Course.Points[#Course.Points - 1],
        Course.Points[#Course.Points], Course.CheckpointRadius),
        "final checkpoint not accepted while parked on penultimate")

    -- Twenty different completed races earn enough for a street coupe.
    for i = 1, 20 do
        local id = "race_sim_" .. tostring(i) .. "_unique"
        check(Rules.AwardCredits(accountA, Course.RewardCredits, id),
            "legitimate race payout " .. i)
        check(not Rules.AwardCredits(accountA, Course.RewardCredits, id),
            "same race reward cannot be replayed " .. i)
        check(Schema.Decode(accountA) ~= nil, "profile remains valid after payout " .. i)
    end
    check(accountA.credits == 13000 and accountB.credits == 0,
        "earning is isolated to vehicle owner")

    check(Rules.PurchaseVehicle(accountA, "street_coupe", "sim_coupe_001",
        "buy_coupe_unique_001"), "buy vehicle")
    check(accountA.credits == 1000, "vehicle cost debited once")
    check(not Rules.PurchaseVehicle(accountA, "street_coupe", "sim_coupe_001",
        "buy_coupe_unique_001"), "replayed car purchase refused")
    check(Rules.SelectVehicle(accountA, "sim_coupe_001"), "select purchased car")
    check(Rules.PurchasePart(accountA, "tire_sport_new", "buy_sport_tire_001"),
        "buy performance tire")
    check(accountA.credits == 100, "part cost debited once")
    check(Rules.InstallPart(accountA, "sim_coupe_001", "tire_sport_new",
        "install_tire_001"), "install tire on owned car")
    check(accountA.garage.sim_coupe_001.tireId == "sport"
        and accountA.inventory.tire_sport_new == nil, "installed part consumed")
    check(not Rules.InstallPart(accountA, "sim_coupe_001", "tire_sport_new",
        "install_tire_001"), "installed part cannot be duplicated")

    local persisted = Schema.Decode(accountA)
    local rejoined = Schema.Decode(persisted)
    check(rejoined ~= nil and rejoined.credits == 100
        and rejoined.selectedVehicleId == "sim_coupe_001", "save and rejoin selection")
    check(rejoined.garage.sim_coupe_001.tireId == "sport", "part remains after rejoin")
    check(not Rules.PurchasePart(rejoined, "tire_sport_new", "buy_sport_tire_001"),
        "replay after rejoin does not mint an item")
    check(accountB.credits == 0 and accountB.garage.sim_coupe_001 == nil,
        "other player unaffected")

    -- Simulate two servers competing for the same cached snapshot.
    local store = {owner = "serverA", data = Schema.New()}
    local firstSuccess = fakeCommit(store, "serverA", function(profile)
        return Rules.AwardCredits(profile, 650, "test_server_0001")
    end)
    check(firstSuccess and store.data.credits == 650, "first writer commits")
    local secondSuccess = fakeCommit(store, "serverB", function(profile)
        return Rules.AwardCredits(profile, 650, "test_server_0002")
    end)
    check(not secondSuccess and store.data.credits == 650,
        "foreign server cannot mutate lease")
    check(Outcome.Classify(true, false, false, true, nil, "serverB", false)
        == "uncertain", "lost ownership fails closed")
    check(Outcome.Classify(true, false, true, false, nil, "serverA", false)
        == "rejected", "business rejection does not masquerade as lost lease")
    check(Outcome.Classify(false, true, false, false, nil, "serverA", false)
        == "uncertain", "write committed but response unavailable is uncertain")

    -- Two players cannot reserve the same deterministic parking geometry.
    local seen = {}
    for slot = 0, Parking.Capacity - 1 do
        local pos = Parking.Position(slot)
        check(pos ~= nil, "parking slot exists " .. slot)
        local key = tostring(pos.X) .. ":" .. tostring(pos.Z)
        check(not seen[key], "parking slot unique " .. slot)
        seen[key] = true
    end
    check(Parking.Position(-1) == nil and Parking.Position(Parking.Capacity) == nil,
        "invalid parking slot rejected")

    print("[StreetCity] PASS: " .. assertions ..
        " gameplay domain simulation assertions (no DataStore / Studio physics)")
end

return Sim
