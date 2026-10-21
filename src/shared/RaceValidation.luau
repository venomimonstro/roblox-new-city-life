--!strict
-- Stateless plausibility checks. Server computes inputs from actual assembly positions.
local RaceValidation = {}

function RaceValidation.PositionPlausible(previous: Vector3, current: Vector3, elapsed: number, maxSpeed: number): boolean
    if elapsed <= 0 or maxSpeed <= 0 then return false end
    return (current - previous).Magnitude <= maxSpeed * elapsed + 10
end

function RaceValidation.CheckpointReached(position: Vector3, target: Vector3, radius: number): boolean
    if radius <= 0 or radius > 50 then return false end
    return (position - target).Magnitude <= radius
end

function RaceValidation.SegmentTimePlausible(fromPoint: Vector3, toPoint: Vector3, elapsed: number, maxSpeed: number): boolean
    if elapsed <= 0 or maxSpeed <= 0 then return false end
    return elapsed >= (toPoint - fromPoint).Magnitude / maxSpeed
end

return table.freeze(RaceValidation)
