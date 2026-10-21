--!strict
-- Deterministic source-level lifecycle simulations. Runs only in Roblox Studio.
-- Fake UpdateAsync has copy semantics and can replay the transform on conflict.
-- Does NOT connect to the real DataStore or claim to be an engine/network test.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Rules = require(Shared:WaitForChild("GarageTransactions"))
local Outcome = require(Shared:WaitForChild("ProfileMutationOutcome"))
local Race = require(Shared:WaitForChild("RaceValidation"))
local Parking = require(Shared:WaitForChild("ParkingLayout"))
local SimulationTests = {}

local function copy(value: any): any
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

local function fakeStore()
    local values: {[string]: any} = {}
    local calls = 0
    local store = {}
    function store:UpdateAsync(key: string, transform: (any) -> any, simulateConflict: boolean?): any
        calls += 1
        local old = copy(values[key])
        if simulateConflict then
            -- UpdateAsync re-invokes the callback before committing on conflict.
            transform(copy(old))
        end
        local proposed = transform(copy(old))
        if proposed == nil then return nil end
        values[key] = copy(proposed)
        return copy(values[key])
    end
    function store:Peek(key: string): any
        return copy(values[key])
    end
    function store:Calls(): number
        return calls
    end
    return store
end

local function acquire(store: any, id: string, owner: string, time: number): any
    return store:UpdateAsync(id, function(old)
        if old and old.owner and old.owner ~= owner
            and (type(old.leaseUntil) ~= "number" or old.leaseUntil > time) then return nil end
        local data = if old then Schema.Decode(old.data) else Schema.New()
        if not data then return nil end
        return {owner = owner, leaseUntil = time + 180, data = data}
    end)
end

local function transact(store: any, id: string, owner: string, edit: (any) -> boolean, retry: boolean?): boolean
    local result = store:UpdateAsync(id, function(old)
        if not old or old.owner ~= owner then return nil end
        local candidate = Schema.Decode(old.data)
        if not candidate or edit(candidate) ~= true or not Schema.Decode(candidate) then return nil end
        return {owner = owner, leaseUntil = old.leaseUntil, data = candidate}
    end, retry)
    return type(result) == "table" and result.owner == owner
end

local function renew(store: any, id: string, owner: string, release: boolean): boolean
    local result = store:UpdateAsync(id, function(old)
        if not old or old.owner ~= owner or not Schema.Decode(old.data) then return nil end
        return {
            owner = if release then nil else owner,
            leaseUntil = if release then 0 else 300,
            data = old.data, -- never overwrite with an outdated cached snapshot
        }
    end)
    return result ~= nil and result.owner == (if release then nil else owner)
end

function SimulationTests.Run()
    local checks = 0
    local function check(predicate: boolean, label: string)
        assert(predicate, "[StreetCity Simulator] " .. label)
        checks += 1
    end

    local store = fakeStore()
    local first = acquire(store, "player_one", "server_A", 100)
    check(first ~= nil and first.owner == "server_A", "initial acquire")
    check(acquire(store, "player_one", "server_B", 110) == nil, "reject active competing server")
    check(acquire(store, "player_one", "server_B", 279) == nil, "reject just-before-expiry takeover")

    local rejected = transact(store, "player_one", "server_A", function(profile)
        return Rules.PurchaseVehicle(profile, "street_coupe", "new_car_0001", "pay_car_0001")
    end)
    check(not rejected, "insufficient credits rejects purchase")
    check(store:Peek("player_one").data.credits == 0, "rejected purchase keeps zero balance")
    check(#store:Peek("player_one").data.recentOperations == 0, "rejected purchase not journaled")

    local operation = "race_award_000001"
    check(transact(store, "player_one", "server_A", function(profile)
        return Rules.AwardCredits(profile, 650, operation)
    end, true), "reward after simulated transform retry")
    check(store:Peek("player_one").data.credits == 650, "retry awards credits only once")
    check(not transact(store, "player_one", "server_A", function(profile)
        return Rules.AwardCredits(profile, 650, operation)
    end), "reject duplicate reward")
    check(store:Peek("player_one").data.credits == 650, "duplicate reward has no effect")

    check(transact(store, "player_one", "server_A", function(profile)
        return Rules.PurchasePart(profile, "tire_worn_used", "purchase_000001")
    end, true), "part purchase with retry")
    check(store:Peek("player_one").data.credits == 550, "part price deducted once")
    check(store:Peek("player_one").data.inventory.tire_worn_used == 1, "purchased inventory stored")
    check(transact(store, "player_one", "server_A", function(profile)
        return Rules.InstallPart(profile, "starter", "tire_worn_used", "install_000001")
    end), "install owned spare part")
    check(store:Peek("player_one").data.garage.starter.tireId == "worn", "installed part restored")
    check(store:Peek("player_one").data.inventory.tire_worn_used == nil, "installation consumes inventory")
    check(not transact(store, "player_one", "server_A", function(profile)
        return Rules.InstallPart(profile, "starter", "tire_worn_used", "install_000002")
    end), "cannot install already consumed part")

    local ownerAView = store:Peek("player_one").data
    check(renew(store, "player_one", "server_A", false), "lease renew succeeds")
    check(store:Peek("player_one").data.credits == ownerAView.credits, "renew does not change data")
    check(renew(store, "player_one", "server_A", true), "lease releases")
    check(acquire(store, "player_one", "server_B", 150) ~= nil, "next server may acquire released profile")
    check(not transact(store, "player_one", "server_A", function(profile)
        return Rules.AwardCredits(profile, 650, "wrong_server_0001")
    end), "old server can no longer write")
    check(store:Peek("player_one").data.credits == 550, "old-server edit does not change balance")
    check(store:Peek("player_one").data.garage.starter.tireId == "worn", "garage survives rejoin")

    local second = acquire(store, "player_two", "server_A", 155)
    check(second ~= nil and second.data.credits == 0, "second player gets independent wallet")
    check(store:Peek("player_one").data.credits == 550, "second player does not alter first wallet")
    check(Outcome.Classify(true, false, true, false, nil, "server_A", false) == "rejected",
        "normal cancelled UpdateAsync does not quarantine")
    check(Outcome.Classify(false, true, false, false, nil, "server_A", false) == "uncertain",
        "timeout-after-commit result is uncertain")
    check(Outcome.Classify(true, true, false, false, {owner = "server_B"}, "server_A", true) == "uncertain",
        "foreign server ownership is never confirmed")

    local occupied: {[string]: boolean} = {}
    for slot = 0, Parking.Capacity - 1 do
        local point = Parking.Position(slot)
        check(point ~= nil and math.abs(point.Z) == 200, "parking slot on intended road")
        local location = tostring(point.X) .. ":" .. tostring(point.Z)
        check(not occupied[location], "parking position unique")
        occupied[location] = true
    end
    check(Parking.Position(Parking.Capacity) == nil, "parking capacity limit")

    local ordered = {
        Vector3.new(0, 1, 23), Vector3.new(0, 1, 100),
        Vector3.new(200, 1, 100), Vector3.new(200, 1, -100),
        Vector3.new(0, 1, -100), Vector3.new(0, 1, 0),
        Vector3.new(0, 1, 23),
    }
    for n = 2, #ordered do
        local before, after = ordered[n - 1], ordered[n]
        check(before.X == after.X or before.Z == after.Z, "race legs follow axes")
        local minTime = (after - before).Magnitude / 145
        check(Race.SegmentTimePlausible(before, after, minTime + 0.01, 145),
            "leg plausible at safe elapsed time")
        check(not Race.SegmentTimePlausible(before, after, minTime * 0.25, 145),
            "shortcut leg rejected")
    end

    print("[StreetCity Simulator] PASS " .. tostring(checks)
        .. " deterministic assertions, fake DataStore calls: " .. tostring(store:Calls()))
end

return SimulationTests
