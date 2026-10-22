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
    matchesRequiredMode: boolean): boolean
    if mode ~= "vehicle" and mode ~= "foot" then return false end
    if seconds < Rules.MinimumTravelSeconds(a, b, mode) then return false end
    if verifiedMovement < Rules.RequiredDistance(a, b) then return false end
    if not matchesRequiredMode then return false end
    if math.abs(position.Y - b.Y) > 12 then return false end
    return (Vector3.new(position.X, 0, position.Z)
        - Vector3.new(b.X, 0, b.Z)).Magnitude <= 18
end
-- An owned car may be parked just outside the mission circle. Do not
-- require the driver to hold the seat while completing a delivery prompt.
-- This is ONLY a mode allowance; the caller must also supply verified
-- in-vehicle movement for the entire required distance.
function Rules.CanDeliverAfterParking(target: Vector3, lastDrivenPos: Vector3?,
    lastDrivenAt: number, now: number, onFootPos: Vector3): boolean
    if not lastDrivenPos or type(lastDrivenAt) ~= "number"
        or now < lastDrivenAt or now - lastDrivenAt > 20 then return false end
    local drivenDistance = (Vector3.new(lastDrivenPos.X, 0, lastDrivenPos.Z)
        - Vector3.new(target.X, 0, target.Z)).Magnitude
    local footDistance = (Vector3.new(onFootPos.X, 0, onFootPos.Z)
        - Vector3.new(target.X, 0, target.Z)).Magnitude
    return drivenDistance <= 25 and footDistance <= 16
        and math.abs(onFootPos.Y - target.Y) <= 12
end

return table.freeze(Rules)
