--!strict
-- V4: backwards compatible with V1/V2/V3 and earlier V4 field sets.
-- No module loading depends on DataStore. Invalid persisted values fail closed.
local Build = require(script.Parent:WaitForChild("VehicleBuild"))
local Vehicles = require(script.Parent:WaitForChild("VehicleCatalog"))
local Offers = require(script.Parent:WaitForChild("ShopCatalog"))
local Properties = require(script.Parent:WaitForChild("PropertyCatalog"))
local Schema = {}

local function integer(value: any, minimum: number, maximum: number): boolean
    return type(value) == "number" and value == value
        and value % 1 == 0 and value >= minimum and value <= maximum
end

local function identifier(value: any, maxLength: number): boolean
    return type(value) == "string" and #value >= 1 and #value <= maxLength
        and value:match("^[%w_%-]+$") ~= nil
end

function Schema.New(userId: number?)
    local variants = {
        "starter_american_sedan", "starter_american_pickup", "starter_american_muscle",
    }
    local catalog = "starter_hatch"
    if type(userId) == "number" and userId >= 1 and userId % 1 == 0 then
        catalog = variants[(userId % #variants) + 1]
    end
    return {
        schemaVersion = 4,
        credits = 0, bankCredits = 0, communityBankCredits = 0,
        stolenGoods = 0, nutrition = 80, fitness = 15, bodyFat = 25,
        allegiance = "independent", allegianceChangedAt = 0,
        guards = 0, henchmen = 0,
        realEstate = {home = 1, rental = 0, shop = 0, lastRentClaim = 0},
        ownedProperties = {},
        selectedVehicleId = "starter",
        garage = {
            starter = {
                catalogId = catalog, engineId = "stock_i4",
                gearboxId = "street_5", tireId = "street",
            },
        },
        inventory = {}, recentOperations = {},
    }
end

function Schema.Decode(raw: any): any?
    if type(raw) ~= "table" or not integer(raw.schemaVersion, 1, 4)
        or not integer(raw.credits, 0, 10000000000)
        or type(raw.garage) ~= "table" then return nil end
    local garage: {[string]: any} = {}
    local count = 0
    for id, vehicle in pairs(raw.garage) do
        count += 1
        if count > 8 or not identifier(id, 64) or type(vehicle) ~= "table" then return nil end
        local catalog = if raw.schemaVersion == 1 then "starter_hatch" else vehicle.catalogId
        if type(catalog) ~= "string" or Vehicles[catalog] == nil
            or not Build.Resolve(vehicle) then return nil end
        garage[id] = {
            catalogId = catalog, engineId = vehicle.engineId,
            gearboxId = vehicle.gearboxId, tireId = vehicle.tireId,
        }
    end
    if not garage.starter then return nil end
    local selected = if raw.schemaVersion == 1 then "starter" else raw.selectedVehicleId
    if not identifier(selected, 64) or not garage[selected] then return nil end

    local inventory: {[string]: number} = {}
    local history: {string} = {}
    if raw.schemaVersion >= 2 then
        if type(raw.inventory) ~= "table"
            or type(raw.recentOperations) ~= "table" then return nil end
        local items = 0
        for id, quantity in pairs(raw.inventory) do
            items += 1
            if items > 48 or not identifier(id, 64) or Offers[id] == nil
                or not integer(quantity, 1, 99) then return nil end
            inventory[id] = quantity
        end
        local n = #raw.recentOperations
        if n > 40 then return nil end
        local seen: {[string]: boolean} = {}
        local total = 0
        for i, operation in pairs(raw.recentOperations) do
            total += 1
            if type(i) ~= "number" or not integer(i, 1, n)
                or not identifier(operation, 64) or seen[operation] then return nil end
            seen[operation] = true
        end
        if total ~= n then return nil end
        for _, operation in ipairs(raw.recentOperations) do
            table.insert(history, operation)
        end
    end

    local bank, loot, nutrition, fitness, fat = 0, 0, 80, 15, 25
    if raw.schemaVersion >= 3 then
        if not integer(raw.bankCredits, 0, 10000000000)
            or not integer(raw.stolenGoods, 0, 20)
            or not integer(raw.nutrition, 0, 100)
            or not integer(raw.fitness, 0, 100)
            or not integer(raw.bodyFat, 5, 80) then return nil end
        bank, loot, nutrition, fitness, fat =
            raw.bankCredits, raw.stolenGoods, raw.nutrition, raw.fitness, raw.bodyFat
    end

    local estate = {home = 1, rental = 0, shop = 0, lastRentClaim = 0}
    local community = 0
    local owned: {[string]: any} = {}
    local allegiance = "independent"
    local changedAt, guards, henchmen = 0, 0, 0
    if raw.schemaVersion == 4 then
        if raw.realEstate ~= nil then
            local value = raw.realEstate
            if type(value) ~= "table" or not integer(value.home, 1, 3)
                or not integer(value.rental, 0, 3)
                or not integer(value.shop, 0, 3)
                or not integer(value.lastRentClaim, 0, 9999999999) then return nil end
            estate = {home = value.home, rental = value.rental,
                shop = value.shop, lastRentClaim = value.lastRentClaim}
        end
        if raw.communityBankCredits ~= nil then
            if not integer(raw.communityBankCredits, 0, 10000000000) then return nil end
            community = raw.communityBankCredits
        end
        if raw.ownedProperties ~= nil then
            if type(raw.ownedProperties) ~= "table" then return nil end
            local total = 0
            for id, property in pairs(raw.ownedProperties) do
                total += 1
                if total > 7 or type(id) ~= "string" or Properties[id] == nil
                    or type(property) ~= "table"
                    or not integer(property.cost, 1, 100000)
                    or type(property.rented) ~= "boolean"
                    or not integer(property.lastPaidAt, 0, 5000000000) then return nil end
                owned[id] = {
                    cost = property.cost, rented = property.rented,
                    lastPaidAt = property.lastPaidAt,
                }
            end
        end
        allegiance = raw.allegiance or "independent"
        changedAt = raw.allegianceChangedAt or 0
        guards = raw.guards or 0
        henchmen = raw.henchmen or 0
        if allegiance ~= "independent" and allegiance ~= "law"
            and allegiance ~= "outlaw"
            or not integer(changedAt, 0, 5000000000)
            or not integer(guards, 0, 3)
            or not integer(henchmen, 0, 3) then return nil end
    end
    return {
        schemaVersion = 4, credits = raw.credits,
        bankCredits = bank, communityBankCredits = community,
        stolenGoods = loot, nutrition = nutrition, fitness = fitness, bodyFat = fat,
        allegiance = allegiance, allegianceChangedAt = changedAt,
        guards = guards, henchmen = henchmen,
        realEstate = estate, ownedProperties = owned,
        selectedVehicleId = selected, garage = garage,
        inventory = inventory, recentOperations = history,
    }
end

return table.freeze(Schema)
