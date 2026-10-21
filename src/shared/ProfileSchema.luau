--!strict
-- Schema V4. Decode migrates V1/V2/V3; unknown future formats fail closed.
local Build = require(script.Parent:WaitForChild("VehicleBuild"))
local Vehicles = require(script.Parent:WaitForChild("VehicleCatalog"))
local Offers = require(script.Parent:WaitForChild("ShopCatalog"))
local Schema = {}
local MAX_CARS = 8
local MAX_ITEMS = 48
local MAX_OPERATIONS = 40

local function finiteInteger(value: any, min: number, max: number): boolean
    return type(value) == "number" and value == value
        and value % 1 == 0 and value >= min and value <= max
end

local function keyOk(value: any): boolean
    return type(value) == "string" and #value >= 1 and #value <= 64
        and string.match(value, "^[%w_%-]+$") ~= nil
end

function Schema.New(userId: number?)
    local starterChoices = {
        "starter_american_sedan", "starter_american_pickup", "starter_american_muscle",
    }
    local starterId = "starter_hatch"
    if type(userId) == "number" and userId >= 1 and userId % 1 == 0 then
        starterId = starterChoices[(userId % #starterChoices) + 1]
    end
    return {
        schemaVersion = 4,
        bankCredits = 0,
        stolenGoods = 0,
        nutrition = 80,
        fitness = 15,
        bodyFat = 25,
        realEstate = {home = 1, rental = 0, shop = 0, lastRentClaim = 0},
        allegiance = "independent",
        allegianceChangedAt = 0,
        guards = 0,
        henchmen = 0,
        credits = 0,
        selectedVehicleId = "starter",
        garage = {
            starter = {
                catalogId = starterId,
                engineId = "stock_i4",
                gearboxId = "street_5",
                tireId = "street",
            },
        },
        inventory = {},
        recentOperations = {},
    }
end

function Schema.Decode(raw: any)
    if type(raw) ~= "table" then return nil end
    if raw.schemaVersion ~= 1 and raw.schemaVersion ~= 2 and raw.schemaVersion ~= 3 and raw.schemaVersion ~= 4 then return nil end
    if not finiteInteger(raw.credits, 0, 10000000000) then return nil end
    if type(raw.garage) ~= "table" then return nil end

    local garage = {}
    local count = 0
    for id, vehicle in pairs(raw.garage) do
        count += 1
        if count > MAX_CARS or not keyOk(id) or type(vehicle) ~= "table" then return nil end
        local catalogId = if raw.schemaVersion == 1 then "starter_hatch" else vehicle.catalogId
        if type(catalogId) ~= "string" or Vehicles[catalogId] == nil then return nil end
        if not Build.Resolve(vehicle) then return nil end
        garage[id] = {
            catalogId = catalogId,
            engineId = vehicle.engineId,
            gearboxId = vehicle.gearboxId,
            tireId = vehicle.tireId,
        }
    end
    if garage.starter == nil then return nil end
    local selection = if raw.schemaVersion == 1 then "starter" else raw.selectedVehicleId
    if not keyOk(selection) or garage[selection] == nil then return nil end

    local inventory = {}
    local operations = {}
    if raw.schemaVersion >= 2 then
        if type(raw.inventory) ~= "table" or type(raw.recentOperations) ~= "table" then return nil end
        local items = 0
        for itemId, qty in pairs(raw.inventory) do
            items += 1
            if items > MAX_ITEMS or not keyOk(itemId) or Offers[itemId] == nil
                or not finiteInteger(qty, 1, 99) then return nil end
            inventory[itemId] = qty
        end
        -- Reject sparse arrays / dictionary fields instead of silently deleting data.
        local opSize = #raw.recentOperations
        local opCount = 0
        for index in pairs(raw.recentOperations) do
            opCount += 1
            if type(index) ~= "number" or index % 1 ~= 0
                or index < 1 or index > opSize then return nil end
        end
        if opCount ~= opSize then return nil end
        local seen = {}
        if opSize > MAX_OPERATIONS then return nil end
        for _, opId in ipairs(raw.recentOperations) do
            if #operations >= MAX_OPERATIONS or not keyOk(opId) or seen[opId] then return nil end
            seen[opId] = true
            table.insert(operations, opId)
        end
    end
    local bankCredits = 0
    local stolenGoods = 0
    local nutrition = 80
    local fitness = 15
    local bodyFat = 25
    if raw.schemaVersion >= 3 then
        if not finiteInteger(raw.bankCredits, 0, 10000000000)
            or not finiteInteger(raw.stolenGoods, 0, 20)
            or not finiteInteger(raw.nutrition, 0, 100)
            or not finiteInteger(raw.fitness, 0, 100)
            or not finiteInteger(raw.bodyFat, 5, 80) then return nil end
        bankCredits = raw.bankCredits
        stolenGoods = raw.stolenGoods
        nutrition = raw.nutrition
        fitness = raw.fitness
        bodyFat = raw.bodyFat
    end
    local realEstate = {home = 1, rental = 0, shop = 0, lastRentClaim = 0}
    if raw.schemaVersion == 4 then
        local data = raw.realEstate
        if type(data) ~= "table"
            or not finiteInteger(data.home, 1, 3)
            or not finiteInteger(data.rental, 0, 3)
            or not finiteInteger(data.shop, 0, 3)
            or not finiteInteger(data.lastRentClaim, 0, 9999999999) then return nil end
        realEstate = {
            home = data.home, rental = data.rental,
            shop = data.shop, lastRentClaim = data.lastRentClaim,
        }
    end
    local allegiance = "independent"
    local allegianceChangedAt = 0
    local guards = 0
    local henchmen = 0
    if raw.schemaVersion == 4 then
        allegiance = raw.allegiance or "independent"
        allegianceChangedAt = raw.allegianceChangedAt or 0
        guards = raw.guards or 0
        henchmen = raw.henchmen or 0
        if allegiance ~= "independent" and allegiance ~= "law"
            and allegiance ~= "outlaw" then return nil end
        if not finiteInteger(allegianceChangedAt, 0, 5000000000)
            or not finiteInteger(guards, 0, 3)
            or not finiteInteger(henchmen, 0, 3) then return nil end
    end
    return {
        schemaVersion = 4,
        allegiance = allegiance,
        allegianceChangedAt = allegianceChangedAt,
        guards = guards,
        henchmen = henchmen,
        realEstate = realEstate,
        bankCredits = bankCredits,
        stolenGoods = stolenGoods,
        nutrition = nutrition,
        fitness = fitness,
        bodyFat = bodyFat,
        credits = raw.credits,
        selectedVehicleId = selection,
        garage = garage,
        inventory = inventory,
        recentOperations = operations,
    }
end

return table.freeze(Schema)
