--!strict
-- Deterministic in-game credit transactions; safe to call repeatedly from
-- ProfileService.Mutate / UpdateAsync transformer. No yielding or external effects.
local Shared = script.Parent
local Vehicles = require(Shared:WaitForChild("VehicleCatalog"))
local Offers = require(Shared:WaitForChild("ShopCatalog"))
local Build = require(Shared:WaitForChild("VehicleBuild"))

local Rules = {}
local MAX_HISTORY = 40
local MAX_CARS = 8

local function record(profile: any, operationId: string): boolean
    if type(operationId) ~= "string" or #operationId < 8 or #operationId > 64
        or not string.match(operationId, "^[%w_%-]+$") then return false end
    for _, previous in profile.recentOperations do
        if previous == operationId then return false end
    end
    table.insert(profile.recentOperations, operationId)
    if #profile.recentOperations > MAX_HISTORY then
        table.remove(profile.recentOperations, 1)
    end
    return true
end

function Rules.PurchaseVehicle(profile: any, catalogId: string, vehicleId: string, operationId: string): boolean
    local definition = Vehicles[catalogId]
    if not definition or definition.price <= 0 or type(vehicleId) ~= "string"
        or #vehicleId < 8 or #vehicleId > 48
        or not string.match(vehicleId, "^[%w_%-]+$")
        or profile.garage[vehicleId] or profile.credits < definition.price then return false end
    local count = 0
    for _ in profile.garage do count += 1 end
    if count >= MAX_CARS then return false end
    if not record(profile, operationId) then return false end
    profile.credits -= definition.price
    profile.garage[vehicleId] = {
        catalogId = catalogId,
        engineId = definition.engineId,
        gearboxId = definition.gearboxId,
        tireId = definition.tireId,
    }
    return true
end

function Rules.PurchasePart(profile: any, offerId: string, operationId: string): boolean
    local offer = Offers[offerId]
    if not offer or profile.credits < offer.price
        or (profile.inventory[offerId] or 0) >= 99 then return false end
    if not record(profile, operationId) then return false end
    profile.credits -= offer.price
    profile.inventory[offerId] = (profile.inventory[offerId] or 0) + 1
    return true
end

function Rules.InstallPart(profile: any, vehicleId: string, offerId: string, operationId: string): boolean
    local car = profile.garage[vehicleId]
    local offer = Offers[offerId]
    if not car or not offer or (profile.inventory[offerId] or 0) < 1
        or car[offer.slot] == offer.partId then return false end
    local candidate = {
        engineId = car.engineId, gearboxId = car.gearboxId, tireId = car.tireId,
    }
    candidate[offer.slot] = offer.partId
    if not Build.Resolve(candidate) then return false end
    if not record(profile, operationId) then return false end
    profile.inventory[offerId] -= 1
    if profile.inventory[offerId] == 0 then profile.inventory[offerId] = nil end
    car[offer.slot] = offer.partId
    return true
end

function Rules.SelectVehicle(profile: any, vehicleId: string): boolean
    if type(vehicleId) ~= "string" or not profile.garage[vehicleId] then return false end
    if profile.selectedVehicleId == vehicleId then return false end
    profile.selectedVehicleId = vehicleId
    return true
end

function Rules.AwardCredits(profile: any, amount: number, operationId: string): boolean
    if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 or amount > 2000
        or profile.credits + amount > 10000000000 then return false end
    if not record(profile, operationId) then return false end
    profile.credits += amount
    return true
end

return table.freeze(Rules)
