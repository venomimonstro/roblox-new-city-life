--!strict
-- Pure city-dynamics simulation, with bounds that prevent runaway growth.
-- This is session-level state. Global persistence needs an authoritative ledger.
local Dynamics = {}

local function bound(n: number): number
    return math.clamp(math.floor(n + 0.5), 0, 100)
end

function Dynamics.New(id: string)
    return {
        id = id, safety = 62, prosperity = 52, bankTrust = 75,
        lawInfluence = 35, outlawInfluence = 15, incidents = 0,
        population = 0, propertyIndex = 100,
    }
end

function Dynamics.Recalculate(state: any)
    state.safety = bound(state.safety)
    state.prosperity = bound(state.prosperity)
    state.bankTrust = bound(state.bankTrust)
    state.lawInfluence = bound(state.lawInfluence)
    state.outlawInfluence = bound(state.outlawInfluence)
    state.population = math.clamp(math.floor(45
        + state.safety * 0.5 + state.prosperity * 0.35), 20, 120)
    state.propertyIndex = math.clamp(math.floor(50
        + state.safety * 0.65 + state.prosperity * 0.6), 45, 175)
end

function Dynamics.Apply(state: any, kind: string, strength: number): boolean
    if type(strength) ~= "number" or strength % 1 ~= 0
        or strength < 1 or strength > 5 then return false end
    if kind == "crime" then
        state.safety -= strength * 3
        state.prosperity -= strength
        state.bankTrust -= strength * 2
        state.outlawInfluence += strength * 2
        state.incidents = math.min(state.incidents + 1, 1000000)
    elseif kind == "civic" then
        state.safety += strength * 2
        state.prosperity += strength * 2
        state.bankTrust += strength
        state.lawInfluence += strength * 2
        state.outlawInfluence -= strength
    elseif kind == "security" then
        state.safety += strength * 3
        state.lawInfluence += strength * 2
        state.outlawInfluence -= strength * 2
    elseif kind == "business" then
        state.prosperity += strength * 3
        state.bankTrust += strength
    else
        return false
    end
    Dynamics.Recalculate(state)
    return true
end

function Dynamics.ResidentCount(state: any): number
    return math.clamp(math.floor(state.population / 25), 1, 5)
end

function Dynamics.BankOperating(state: any): boolean
    return state.bankTrust >= 20
end

function Dynamics.MarketPrice(basePrice: number, state: any): number
    return math.max(1, math.floor(basePrice * state.propertyIndex / 100))
end

return table.freeze(Dynamics)
