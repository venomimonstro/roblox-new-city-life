--!strict
-- Schema V2. Decode accepts V1; unknown future formats fail closed.
local Build = require(script.Parent:WaitForChild("VehicleBuild"))
local Vehicles = require(script.Parent:WaitForChild("VehicleCatalog"))
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

function Schema.New()
    return {
        schemaVersion = 2,
        credits = 0,
        selectedVehicleId = "starter",
        garage = {
            starter = {
                catalogId = "starter_hatch",
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
    if raw.schemaVersion ~= 1 and raw.schemaVersion ~= 2 then return nil end
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
    if raw.schemaVersion == 2 then
        if type(raw.inventory) ~= "table" or type(raw.recentOperations) ~= "table" then return nil end
        local items = 0
        for itemId, qty in pairs(raw.inventory) do
            items += 1
            if items > MAX_ITEMS or not keyOk(itemId) or not finiteInteger(qty, 1, 99) then return nil end
            inventory[itemId] = qty
        end
        local seen = {}
        for _, opId in ipairs(raw.recentOperations) do
            if #operations >= MAX_OPERATIONS or not keyOk(opId) or seen[opId] then return nil end
            seen[opId] = true
            table.insert(operations, opId)
        end
    end
    return {
        schemaVersion = 2,
        credits = raw.credits,
        selectedVehicleId = selection,
        garage = garage,
        inventory = inventory,
        recentOperations = operations,
    }
end

return table.freeze(Schema)
