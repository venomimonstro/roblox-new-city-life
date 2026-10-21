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
    if not car or not offer or (offer.slot ~= "engineId"
        and offer.slot ~= "gearboxId" and offer.slot ~= "tireId")
        or (profile.inventory[offerId] or 0) < 1
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

-- Reusable debit for server-authorized services such as guarding/police grants.
function Rules.SpendCredits(profile: any, amount: number, operationId: string): boolean
    if type(amount) ~= "number" or amount % 1 ~= 0
        or amount < 1 or amount > 100000
        or type(profile.credits) ~= "number" or profile.credits < amount then return false end
    if not record(profile, operationId) then return false end
    profile.credits -= amount
    return true
end

function Rules.CollectEquipment(profile: any, offerId: string, operationId: string): boolean
    local offer = Offers[offerId]
    if not offer or offer.slot ~= "gear"
        or (profile.inventory[offerId] or 0) > 0 then return false end
    if not record(profile, operationId) then return false end
    profile.inventory[offerId] = 1
    return true
end

-- Wallet vs secured bank. Server supplies fixed transfer amount; never
-- client-reported balances. Repeated UpdateAsync callbacks see new snapshots.
function Rules.TransferBank(profile: any, amount: number, deposit: boolean, operationId: string): boolean
    if type(deposit) ~= "boolean" or type(amount) ~= "number"
        or amount % 1 ~= 0 or amount < 1 or amount > 2000 then return false end
    if type(profile.bankCredits) ~= "number" then return false end
    if deposit then
        if profile.credits < amount or profile.bankCredits + amount > 10000000000 then return false end
    elseif profile.bankCredits < amount or profile.credits + amount > 10000000000 then
        return false
    end
    if not record(profile, operationId) then return false end
    profile.credits += if deposit then -amount else amount
    profile.bankCredits += if deposit then amount else -amount
    return true
end

-- Loot is merchandise, not spendable cash. A fence must pay for it separately.
function Rules.StealGoods(profile: any, units: number, operationId: string): boolean
    if type(units) ~= "number" or units % 1 ~= 0
        or units < 1 or units > 4 or type(profile.stolenGoods) ~= "number"
        or profile.stolenGoods + units > 20 then return false end
    if not record(profile, operationId) then return false end
    profile.stolenGoods += units
    return true
end

function Rules.FenceGoods(profile: any, units: number, operationId: string): boolean
    if type(units) ~= "number" or units % 1 ~= 0 or units < 1 or units > 10
        or type(profile.stolenGoods) ~= "number" or profile.stolenGoods < units
        or profile.credits + units * 180 > 10000000000 then return false end
    if not record(profile, operationId) then return false end
    profile.stolenGoods -= units
    profile.credits += units * 180
    return true
end

function Rules.EatFood(profile: any, price: number, nutrition: number, fat: number,
    operationId: string): boolean
    if type(price) ~= "number" or price % 1 ~= 0 or price < 1 or price > 200
        or type(nutrition) ~= "number" or nutrition % 1 ~= 0
        or nutrition < 1 or nutrition > 40 or fat < 0 or fat > 10
        or profile.credits < price or type(profile.nutrition) ~= "number"
        or type(profile.bodyFat) ~= "number" then return false end
    if not record(profile, operationId) then return false end
    profile.credits -= price
    profile.nutrition = math.clamp(profile.nutrition + nutrition, 0, 100)
    profile.bodyFat = math.clamp(profile.bodyFat + fat, 5, 80)
    return true
end

function Rules.Workout(profile: any, gain: number, operationId: string): boolean
    if type(gain) ~= "number" or gain % 1 ~= 0
        or gain < 1 or gain > 6 or type(profile.fitness) ~= "number"
        or type(profile.bodyFat) ~= "number"
        or type(profile.nutrition) ~= "number"
        or profile.nutrition < 5 then return false end
    if not record(profile, operationId) then return false end
    profile.fitness = math.clamp(profile.fitness + gain, 0, 100)
    profile.bodyFat = math.clamp(profile.bodyFat - 1, 5, 80)
    profile.nutrition = math.max(0, profile.nutrition - 5)
    return true
end

-- These assets are PER-PLAYER deeds, not ownership of globally unique land.
local DEED_BASE = {home = 6500, rental = 12000, shop = 26000}

function Rules.BuyDeed(profile: any, kind: string, price: number, operationId: string): boolean
    local properties = profile.realEstate
    if not properties or not DEED_BASE[kind]
        or type(price) ~= "number" or price % 1 ~= 0 or price < 2000
        or price > 100000 or type(properties[kind]) ~= "number"
        or properties[kind] >= 3 or profile.credits < price then return false end
    if not record(profile, operationId) then return false end
    properties[kind] += 1
    profile.credits -= price
    return true
end

function Rules.SellDeed(profile: any, kind: string, payout: number, operationId: string): boolean
    local properties = profile.realEstate
    if not properties or (kind ~= "rental" and kind ~= "shop")
        or properties[kind] < 1 or type(payout) ~= "number"
        or payout % 1 ~= 0 or payout < 500 or payout > 100000
        or profile.credits + payout > 10000000000 then return false end
    if not record(profile, operationId) then return false end
    properties[kind] -= 1
    profile.credits += payout
    return true
end

function Rules.CollectRent(profile: any, serverNow: number,
    amount: number, operationId: string): boolean
    local deed = profile.realEstate
    if not deed or deed.rental + deed.shop < 1
        or type(serverNow) ~= "number" or serverNow % 1 ~= 0
        or serverNow < 1000000000 or serverNow > 9999999999
        or serverNow - deed.lastRentClaim < 900
        or type(amount) ~= "number" or amount % 1 ~= 0
        or amount < 1 or amount > 2000
        or profile.bankCredits + amount > 10000000000 then return false end
    if not record(profile, operationId) then return false end
    deed.lastRentClaim = serverNow
    profile.bankCredits += amount
    return true
end

function Rules.SetAllegiance(profile: any, allegiance: string,
    now: number): boolean
    if allegiance ~= "independent" and allegiance ~= "law"
        and allegiance ~= "outlaw" then return false end
    if profile.allegiance == allegiance or type(now) ~= "number"
        or now % 1 ~= 0 or now < 1000000000 or now > 5000000000
        or type(profile.allegianceChangedAt) ~= "number"
        or now - profile.allegianceChangedAt < 900 then return false end
    if profile.henchmen > 0 and allegiance == "law" then return false end
    if profile.guards > 0 and allegiance == "outlaw" then return false end
    profile.allegiance = allegiance
    profile.allegianceChangedAt = now
    return true
end

function Rules.HireFollower(profile: any, role: string, operationId: string): boolean
    local cost = if role == "guard" then 1400 elseif role == "henchman" then 1100 else 0
    local key = if role == "guard" then "guards" else "henchmen"
    if cost == 0 or type(profile[key]) ~= "number"
        or profile[key] >= 3 or profile.credits < cost
        or (role == "guard" and profile.allegiance == "outlaw")
        or (role == "henchman" and profile.allegiance == "law") then return false end
    if not record(profile, operationId) then return false end
    profile.credits -= cost
    profile[key] += 1
    return true
end

function Rules.LoseFollower(profile: any, role: string): boolean
    if role ~= "guard" and role ~= "henchman" then return false end
    local key = if role == "guard" then "guards" else "henchmen"
    if type(profile[key]) ~= "number" or profile[key] < 1 then return false end
    profile[key] -= 1
    return true
end

return table.freeze(Rules)
