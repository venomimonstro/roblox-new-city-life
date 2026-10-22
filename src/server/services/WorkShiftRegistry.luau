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

function Registry.Active(userId: number): string?
    return ownership[userId]
end

return Registry
