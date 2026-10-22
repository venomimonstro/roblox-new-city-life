--!strict
-- One active paid career shift across all public job modules in this server.
local Registry = {}
local ownership: {[number]: string} = {}

function Registry.Claim(userId: number, jobKey: string): boolean
    if type(userId) ~= "number" or type(jobKey) ~= "string"
        or #jobKey < 3 or #jobKey > 64 or ownership[userId] ~= nil then
        return false
    end
    ownership[userId] = jobKey
    return true
end

function Registry.Release(userId: number, jobKey: string): boolean
    if ownership[userId] ~= jobKey then return false end
    ownership[userId] = nil
    return true
end

-- Immutable first acceptance timestamp determines expiry. Anti-teleport route
-- resets are not allowed to indefinitely extend a shift.
function Registry.Expired(startedAt: number, now: number): boolean
    if type(startedAt) ~= "number" or type(now) ~= "number"
        or startedAt ~= startedAt or now ~= now
        or startedAt < 0 or now < startedAt then return true end
    return now - startedAt >= 1200
end

function Registry.Active(userId: number): string?
    return ownership[userId]
end

return Registry
