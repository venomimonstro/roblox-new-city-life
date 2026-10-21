--!strict
local VehicleMath = {}

function VehicleMath.StudsPerSecondToKmh(speed: number): number
    return math.max(0, speed) * 0.28 * 3.6
end

function VehicleMath.TractionFactor(material: Enum.Material): number
    if material == Enum.Material.Ice then
        return 0.25
    elseif material == Enum.Material.Sand or material == Enum.Material.Mud then
        return 0.57
    elseif material == Enum.Material.Grass then
        return 0.75
    end
    return 1
end

function VehicleMath.SpringAcceleration(compression: number, verticalSpeed: number, stiffness: number, damping: number): number
    return math.max(0, math.clamp(compression, 0, 1) * stiffness - verticalSpeed * damping)
end

function VehicleMath.ContactTraction(contacts: number): number
    return math.clamp(contacts / 4, 0, 1)
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
    steer: number, longitudinalSpeed: number, maxRate: number
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
