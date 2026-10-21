--!strict
local VehicleMath = {}

function VehicleMath.StudsPerSecondToKmh(speed: number): number
    -- Roblox's conventional approximation: 1 stud = 0.28 meters.
    return math.max(0, speed) * 0.28 * 3.6
end

function VehicleMath.DriveAcceleration(
    throttle: number,
    longitudinalSpeed: number,
    forwardAcceleration: number,
    reverseAcceleration: number,
    maxForwardSpeed: number,
    maxReverseSpeed: number
): number
    throttle = math.clamp(throttle, -1, 1)
    if throttle > 0 and longitudinalSpeed >= maxForwardSpeed then
        return 0
    end
    if throttle < 0 and longitudinalSpeed <= -maxReverseSpeed then
        return 0
    end
    return throttle * (throttle < 0 and reverseAcceleration or forwardAcceleration)
end

function VehicleMath.SteeringAngularSpeed(
    steer: number,
    longitudinalSpeed: number,
    maxRate: number
): number
    local speed = math.abs(longitudinalSpeed)
    if speed < 1 then
        return 0
    end
    local engagement = math.clamp(speed / 14, 0, 1)
    local highSpeedReduction = math.clamp(1 - speed / 155, 0.3, 1)
    local reverse = if longitudinalSpeed < 0 then -1 else 1
    return -math.clamp(steer, -1, 1) * maxRate * engagement * highSpeedReduction * reverse
end

return table.freeze(VehicleMath)
