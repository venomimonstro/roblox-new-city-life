--!strict
-- Pure, deterministic mission validation; callbacks are server-only.
local Rules = {}
function Rules.MinimumTravelSeconds(a: Vector3, b: Vector3, mode: string): number
    local distance = (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
    return math.max(if mode == "vehicle" then 10 else 14,
        distance / (if mode == "vehicle" then 100 else 16) + 5)
end
function Rules.RequiredDistance(a: Vector3, b: Vector3): number
    return math.max(45, (Vector3.new(a.X, 0, a.Z)
        - Vector3.new(b.X, 0, b.Z)).Magnitude * 0.6)
end
function Rules.CanFinishLeg(a: Vector3, b: Vector3, position: Vector3,
    seconds: number, verifiedMovement: number, mode: string,
    validTransport: boolean): boolean
    if mode ~= "vehicle" and mode ~= "foot" then return false end
    if seconds < Rules.MinimumTravelSeconds(a, b, mode) then return false end
    if verifiedMovement < Rules.RequiredDistance(a, b) then return false end
    if mode == "vehicle" and not validTransport then return false end
    if mode == "foot" and validTransport then return false end
    if math.abs(position.Y - b.Y) > 12 then return false end
    return (Vector3.new(position.X, 0, position.Z)
        - Vector3.new(b.X, 0, b.Z)).Magnitude <= 18
end
return table.freeze(Rules)
