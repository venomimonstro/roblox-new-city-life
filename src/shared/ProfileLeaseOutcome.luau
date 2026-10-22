--!strict
-- UpdateAsync can return a readable prior value even if a transform was
-- canceled. Only a transform that actually supplied the committed value is
-- proof of lease renewal or release.
local LeaseOutcome = {}

function LeaseOutcome.Confirmed(
    requestSucceeded: boolean,
    writtenInTransform: boolean,
    response: any,
    expectedToken: string,
    release: boolean,
    dataValid: boolean
): boolean
    if not requestSucceeded or not writtenInTransform or not dataValid
        or type(response) ~= "table" then return false end
    if release then
        return response.owner == nil and response.leaseUntil == 0
    end
    return response.owner == expectedToken
        and type(response.leaseUntil) == "number"
        and response.leaseUntil > 0
end

return table.freeze(LeaseOutcome)
