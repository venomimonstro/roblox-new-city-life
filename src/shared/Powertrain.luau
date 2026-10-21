--!strict
-- Pure, deterministic drivetrain calculations; no Instances or network requests.
local Powertrain = {}

export type Spec = {
    idleRpm: number, redlineRpm: number, peakRpm: number,
    peakTorqueNm: number, ratios: {number}, finalDrive: number,
    tireRadiusM: number, efficiency: number,
}
export type State = { gear: number, rpm: number }

function Powertrain.Validate(s: Spec): boolean
    if s.idleRpm < 300 or s.redlineRpm <= s.idleRpm or s.peakRpm < s.idleRpm
        or s.peakRpm > s.redlineRpm or s.peakTorqueNm <= 0
        or s.finalDrive <= 0 or s.tireRadiusM <= 0.1 or s.efficiency <= 0 or s.efficiency > 1
        or #s.ratios < 1 or #s.ratios > 8 then return false end
    for _, ratio in s.ratios do
        if ratio <= 0 or ratio > 8 then return false end
    end
    return true
end

function Powertrain.Torque(s: Spec, rpm: number): number
    local r = math.clamp(rpm, s.idleRpm, s.redlineRpm)
    local distance = math.abs(r - s.peakRpm)
    local span = if r < s.peakRpm then s.peakRpm - s.idleRpm else s.redlineRpm - s.peakRpm
    return s.peakTorqueNm * math.clamp(1 - 0.55 * distance / math.max(1, span), 0.25, 1)
end

function Powertrain.EngineRpm(s: Spec, gear: number, speedMps: number): number
    local ratio = s.ratios[gear]
    if not ratio then return s.idleRpm end
    local wheelRpm = math.abs(speedMps) * 60 / (2 * math.pi * s.tireRadiusM)
    return math.clamp(wheelRpm * ratio * s.finalDrive, s.idleRpm, s.redlineRpm)
end

function Powertrain.WheelForce(s: Spec, rpm: number, gear: number): number
    local ratio = s.ratios[gear]
    if not ratio then return 0 end
    return Powertrain.Torque(s, rpm) * ratio * s.finalDrive * s.efficiency / s.tireRadiusM
end

function Powertrain.Shift(s: Spec, state: State, throttle: number): number
    local gear = math.clamp(state.gear, 1, #s.ratios)
    if state.rpm > s.redlineRpm * 0.92 and gear < #s.ratios and throttle > 0.15 then
        return gear + 1
    elseif state.rpm < s.peakRpm * 0.55 and gear > 1 then
        return gear - 1
    end
    return gear
end

return table.freeze(Powertrain)
