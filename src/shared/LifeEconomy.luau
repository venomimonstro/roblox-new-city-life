--!strict
-- Pure transactional game economy for death, protected cash and public safety.
-- Explicitly non-paywall: unpaid clinic recovery always restores playability.
local Districts = require(script.Parent:WaitForChild("DistrictConfig"))
local Economy = {}
local MAX_MONEY = 10000000000
local districtIds = {}
for _, district in Districts do districtIds[district.id] = true end

local function op(profile: any, id: string): boolean
    if type(id) ~= "string" or #id < 8 or #id > 64
        or not id:match("^[%w_%-]+$") then return false end
    for _, previous in profile.recentOperations do
        if previous == id then return false end
    end
    table.insert(profile.recentOperations, id)
    if #profile.recentOperations > 40 then table.remove(profile.recentOperations, 1) end
    return true
end

function Economy.TransferHome(profile: any, amount: number, deposit: boolean,
    operationId: string): boolean
    if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 1
        or amount > 2000 or type(deposit) ~= "boolean"
        or type(profile.homeCredits) ~= "number" then return false end
    if deposit then
        if profile.credits < amount or profile.homeCredits + amount > MAX_MONEY then return false end
    elseif profile.homeCredits < amount or profile.credits + amount > MAX_MONEY then
        return false
    end
    if not op(profile, operationId) then return false end
    profile.credits += if deposit then -amount else amount
    profile.homeCredits += if deposit then amount else -amount
    return true
end

function Economy.DeathSettlement(profile: any, wantedLevel: number,
    operationId: string): boolean
    if type(profile.credits) ~= "number" or type(profile.bankCredits) ~= "number"
        or type(profile.medicalDebt) ~= "number" or type(profile.deathCount) ~= "number"
        or type(wantedLevel) ~= "number" or wantedLevel % 1 ~= 0
        or wantedLevel < 0 or wantedLevel > 5 then return false end
    -- An insolvent player must never lose the free respawn path just because
    -- unpaid medical debt or lifetime death statistics reached schema limits.
    -- Clamp bounded counters while still settling the current loss.
    if not op(profile, operationId) then return false end
    -- Unprotected carried cash suffers a predictable robbery/accident loss.
    local pocketLoss = math.min(profile.credits,
        math.floor(profile.credits * (0.15 + wantedLevel * 0.035)))
    profile.credits -= pocketLoss
    local careFee = 350 + wantedLevel * 90
    -- Cash first, then savings; money stored at home remains protected.
    local fromPocket = math.min(profile.credits, careFee)
    profile.credits -= fromPocket
    local due = careFee - fromPocket
    local fromBank = math.min(profile.bankCredits, due)
    profile.bankCredits -= fromBank
    due -= fromBank
    profile.medicalDebt = math.min(1000000, profile.medicalDebt + due)
    profile.deathCount = math.min(100000000, profile.deathCount + 1)
    -- NO paid resurrection. Inability to pay yields recorded debt and
    -- an accessible public clinic, never forced Robux purchasing.
    return true
end

function Economy.PayMedicalDebt(profile: any, amount: number, operationId: string): boolean
    if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 or amount > 2000
        or type(profile.medicalDebt) ~= "number"
        or profile.medicalDebt < amount or profile.credits < amount then return false end
    if not op(profile, operationId) then return false end
    profile.medicalDebt -= amount
    profile.credits -= amount
    return true
end

function Economy.InvestSafety(profile: any, districtId: string,
    operationId: string): boolean
    if not districtIds[districtId] or type(profile.securityBonds) ~= "table"
        or profile.credits < 1250 then return false end
    local owned = profile.securityBonds[districtId] or 0
    if owned >= 3 then return false end
    if not op(profile, operationId) then return false end
    profile.credits -= 1250
    profile.securityBonds[districtId] = owned + 1
    return true
end

function Economy.SecurityDividend(profile: any, districtId: string,
    operationId: string): boolean
    local shares = type(profile.securityBonds) == "table"
        and profile.securityBonds[districtId] or 0
    if type(shares) ~= "number" or shares < 1 or shares > 3
        or profile.bankCredits + shares * 30 > MAX_MONEY then return false end
    if not op(profile, operationId) then return false end
    profile.bankCredits += shares * 30
    return true
end

function Economy.BountyReward(profile: any, stars: number,
    operationId: string, victimUserId: number?, paidAt: number?): boolean
    if type(stars) ~= "number" or stars % 1 ~= 0
        or stars < 3 or stars > 5 then return false end
    local payout = 320 + stars * 200
    if profile.bankCredits + payout > MAX_MONEY then return false end
    local claimKey: string? = nil
    if victimUserId ~= nil or paidAt ~= nil then
        if type(victimUserId) ~= "number" or victimUserId % 1 ~= 0
            or victimUserId < 1 or victimUserId > 1000000000000000
            or type(paidAt) ~= "number" or paidAt % 1 ~= 0
            or paidAt < 1000000000 or paidAt > 5000000000
            or type(profile.bountyClaims) ~= "table" then return false end
        claimKey = tostring(victimUserId)
        local previous = profile.bountyClaims[claimKey]
        if previous and paidAt - previous < 1800 then return false end
    end
    if not op(profile, operationId) then return false end
    profile.bankCredits += payout
    if claimKey and paidAt then
        -- Separate durable deduplication: the short 40-operation wallet journal
        -- can roll over during regular shopping without reopening bounty claims.
        profile.bountyClaims[claimKey] = paidAt
        local count = 0
        local oldestKey: string? = nil
        local oldestTime = math.huge
        for key, timestamp in pairs(profile.bountyClaims) do
            count += 1
            if timestamp < oldestTime then
                oldestKey, oldestTime = key, timestamp
            end
        end
        if count > 20 and oldestKey then
            profile.bountyClaims[oldestKey] = nil
        end
    end
    return true
end

return table.freeze(Economy)
