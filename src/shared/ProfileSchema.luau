--!strict
-- V4 combined migration: original cars/economy + civic affiliations and
-- player-instanced property deeds. Never discard fields during Decode.
local Build = require(script.Parent:WaitForChild("VehicleBuild"))
local Vehicles = require(script.Parent:WaitForChild("VehicleCatalog"))
local Offers = require(script.Parent:WaitForChild("ShopCatalog"))
local Properties = require(script.Parent:WaitForChild("PropertyCatalog"))
local Schema = {}
local MAX_CARS = 8
local MAX_ITEMS = 48
local MAX_OPERATIONS = 40
local MAX_DEEDS = 7

local function int(value: any, min: number, max: number): boolean
    return type(value) == "number" and value == value
        and value % 1 == 0 and value >= min and value <= max
end

local function key(value: any): boolean
    return type(value) == "string" and #value >= 1 and #value <= 64
        and value:match("^[%w_%-]+$") ~= nil
end

function Schema.New(userId: number?)
    local starters = {"starter_american_sedan", "starter_american_pickup",
        "starter_american_muscle"}
    local starterId = "starter_hatch"
    if int(userId, 1, 1000000000000000) then
        starterId = starters[(userId % #starters) + 1]
    end
    return {
        schemaVersion = 4,
        credits = 0, bankCredits = 0, communityBankCredits = 0, stolenGoods = 0,
        nutrition = 80, fitness = 15, bodyFat = 25,
        allegiance = "independent", allegianceChangedAt = 0,
        guards = 0, henchmen = 0,
        realEstate = {home = 1, rental = 0, shop = 0, lastRentClaim = 0},
        ownedProperties = {},
        selectedVehicleId = "starter",
        garage = {starter = {catalogId = starterId, engineId = "stock_i4",
            gearboxId = "street_5", tireId = "street"}},
        inventory = {},
        recentOperations = {},
    }
end

function Schema.Decode(raw: any): any?
    if type(raw) ~= "table" or not int(raw.schemaVersion, 1, 4)
        or not int(raw.credits, 0, 10000000000)
        or type(raw.garage) ~= "table" then return nil end
    local garage = {}
    local vehicleCount = 0
    for id, vehicle in pairs(raw.garage) do
        vehicleCount += 1
        if vehicleCount > MAX_CARS or not key(id) or type(vehicle) ~= "table" then return nil end
        local catalogId = if raw.schemaVersion == 1 then "starter_hatch" else vehicle.catalogId
        if type(catalogId) ~= "string" or not Vehicles[catalogId]
            or not Build.Resolve(vehicle) then return nil end
        garage[id] = {
            catalogId = catalogId, engineId = vehicle.engineId,
            gearboxId = vehicle.gearboxId, tireId = vehicle.tireId,
        }
    end
    if not garage.starter then return nil end
    local selected = if raw.schemaVersion == 1 then "starter" else raw.selectedVehicleId
    if not key(selected) or not garage[selected] then return nil end

    local inventory = {}
    local operations = {}
    if raw.schemaVersion >= 2 then
        if type(raw.inventory) ~= "table" or type(raw.recentOperations) ~= "table" then return nil end
        local count = 0
        for sku, quantity in pairs(raw.inventory) do
            count += 1
            if count > MAX_ITEMS or not key(sku) or Offers[sku] == nil
                or not int(quantity, 1, 99) then return nil end
            inventory[sku] = quantity
        end
        local size = #raw.recentOperations
        if size > MAX_OPERATIONS then return nil end
        local exactCount = 0
        for index in pairs(raw.recentOperations) do
            exactCount += 1
            if not int(index, 1, size) then return nil end
        end
        if exactCount ~= size then return nil end
        local seen = {}
        for _, op in ipairs(raw.recentOperations) do
            if not key(op) or seen[op] then return nil end
            seen[op] = true
            table.insert(operations, op)
        end
    end

    local bankCredits, stolenGoods, nutrition, fitness, bodyFat = 0, 0, 80, 15, 25
    if raw.schemaVersion >= 3 then
        if not int(raw.bankCredits, 0, 10000000000)
            or not int(raw.stolenGoods, 0, 20)
            or not int(raw.nutrition, 0, 100)
            or not int(raw.fitness, 0, 100)
            or not int(raw.bodyFat, 5, 80) then return nil end
        bankCredits, stolenGoods = raw.bankCredits, raw.stolenGoods
        nutrition, fitness, bodyFat = raw.nutrition, raw.fitness, raw.bodyFat
    end

    -- Both V4 development branches can exist in storage. Missing fields are
    -- initialized without discarding the other branch's valid possessions.
    local communityBankCredits = 0
    local deeds = {}
    local propertyInfo = {home = 1, rental = 0, shop = 0, lastRentClaim = 0}
    local allegiance, allegianceChangedAt, guards, henchmen = "independent", 0, 0, 0
    if raw.schemaVersion == 4 then
        local savings = raw.communityBankCredits
        if savings ~= nil then
            if not int(savings, 0, 10000000000) then return nil end
            communityBankCredits = savings
        end
        local owned = raw.ownedProperties
        if owned ~= nil then
            if type(owned) ~= "table" then return nil end
            local count = 0
            for id, deed in pairs(owned) do
                count += 1
                if count > MAX_DEEDS or not key(id) or not Properties[id]
                    or type(deed) ~= "table"
                    or not int(deed.cost, 1, 100000)
                    or type(deed.rented) ~= "boolean"
                    or not int(deed.lastPaidAt, 0, 5000000000) then return nil end
                deeds[id] = {cost = deed.cost, rented = deed.rented,
                    lastPaidAt = deed.lastPaidAt}
            end
        end
        local other = raw.realEstate
        if other ~= nil then
            if type(other) ~= "table" or not int(other.home, 1, 3)
                or not int(other.rental, 0, 3)
                or not int(other.shop, 0, 3)
                or not int(other.lastRentClaim, 0, 9999999999) then return nil end
            propertyInfo = {home = other.home, rental = other.rental,
                shop = other.shop, lastRentClaim = other.lastRentClaim}
        end
        allegiance = raw.allegiance or "independent"
        allegianceChangedAt = raw.allegianceChangedAt or 0
        guards, henchmen = raw.guards or 0, raw.henchmen or 0
        if allegiance ~= "independent" and allegiance ~= "law"
            and allegiance ~= "outlaw" then return nil end
        if not int(allegianceChangedAt, 0, 5000000000)
            or not int(guards, 0, 3) or not int(henchmen, 0, 3) then return nil end
    end
    return {
        schemaVersion = 4, credits = raw.credits,
        bankCredits = bankCredits, communityBankCredits = communityBankCredits,
        stolenGoods = stolenGoods, nutrition = nutrition, fitness = fitness,
        bodyFat = bodyFat, realEstate = propertyInfo, ownedProperties = deeds,
        allegiance = allegiance, allegianceChangedAt = allegianceChangedAt,
        guards = guards, henchmen = henchmen,
        selectedVehicleId = selected, garage = garage,
        inventory = inventory, recentOperations = operations,
    }
end

return table.freeze(Schema)
