--!strict
-- Pure classification of an UpdateAsync mutation outcome.
-- A callback returning nil cancels the write and UpdateAsync can itself return nil.
local Outcome = {}

function Outcome.Classify(
    requestSucceeded: boolean,
    acceptedInTransform: boolean,
    rejectedByRule: boolean,
    invalidOrLost: boolean,
    response: any,
    expectedToken: string,
    dataValid: boolean
): string
    if requestSucceeded and acceptedInTransform and not rejectedByRule
        and not invalidOrLost and dataValid
        and type(response) == "table" and response.owner == expectedToken then
        return "committed"
    end
    if requestSucceeded and rejectedByRule and not acceptedInTransform
        and not invalidOrLost and response == nil then
        return "rejected"
    end
    return "uncertain"
end

return table.freeze(Outcome)
