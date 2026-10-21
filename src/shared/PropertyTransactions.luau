--!strict
-- Pure property/deposit mutations. Rights are player-instanced, never exclusive
-- public land titles. No client-supplied prices, balances, or timestamps.
local Properties = require(script.Parent:WaitForChild("PropertyCatalog"))
local Wallet = require(script.Parent:WaitForChild("GarageTransactions"))
local Rules = {}

local function record(profile: any, opId: string): boolean
    if type(opId) ~= "string" or #opId < 8 or #opId > 64
        or not opId:match("^[%w_%-]+$") then return false end
    for _, previous in profile.recentOperations do
        if previous == opId then return false end
    end
    table.insert(profile.recentOperations, opId)
    if #profile.recentOperations > 40 then table.remove(profile.recentOperations, 1) end
    return true
end

function Rules.Buy(profile: any, id: string, quotedPrice: number, opId: string): boolean
    if not Properties[id] or profile.ownedProperties[id]
        or type(quotedPrice) ~= "number" or quotedPrice % 1 ~= 0
        or quotedPrice < 500 or quotedPrice > 100000 then return false end
    if not Wallet.SpendCredits(profile, quotedPrice, opId) then return false end
    profile.ownedProperties[id] = {
        cost = quotedPrice,
        rented = false,
        lastPaidAt = 0,
    }
    return true
end

function Rules.SellToCity(profile: any, id: string, opId: string): boolean
    local deed = profile.ownedProperties[id]
    if not Properties[id] or not deed then return false end
    local amount = math.floor(deed.cost * 0.7)
    if amount < 1 or profile.credits + amount > 10000000000
        or not record(profile, opId) then return false end
    profile.credits += amount
    profile.ownedProperties[id] = nil
    return true
end

function Rules.SetRental(profile: any, id: string, rented: boolean): boolean
    local deed = profile.ownedProperties[id]
    if not Properties[id] or not deed or type(rented) ~= "boolean"
        or deed.rented == rented then return false end
    deed.rented = rented
    if rented then
        -- First rental requires a real elapsed lease period; no immediate payout.
        deed.lastPaidAt = os.time()
    end
    return true
end

function Rules.CollectRent(profile: any, id: string, now: number, opId: string): boolean
    local deed = profile.ownedProperties[id]
    local offer = Properties[id]
    if not offer or not deed or not deed.rented
        or type(now) ~= "number" or now % 1 ~= 0 or now < 0
        or now - deed.lastPaidAt < 300 then return false end
    if not Wallet.AwardCredits(profile, offer.rent, opId) then return false end
    deed.lastPaidAt = now
    return true
end

function Rules.CommunityBank(profile: any, amount: number, deposit: boolean, opId: string): boolean
    if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 1
        or amount > 2000 or type(deposit) ~= "boolean" then return false end
    if deposit then
        if profile.communityBankCredits + amount > 10000000000
            or not Wallet.SpendCredits(profile, amount, opId) then return false end
        profile.communityBankCredits += amount
    else
        if profile.communityBankCredits < amount
            or not Wallet.AwardCredits(profile, amount, opId) then return false end
        profile.communityBankCredits -= amount
    end
    return true
end

return table.freeze(Rules)
