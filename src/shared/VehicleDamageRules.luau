--!strict
-- Pure physical damage model: studs/second are game units, not literal km/h.
-- Explosions are a disabled gameplay event by default, never a side effect of
-- falling through streamed terrain. Ownership is persisted separately.
local Damage = {}
function Damage.Impact(deltaSpeed: number, speedBefore: number,
    grounded: boolean, playerOccupied: boolean): {damage: number, occupantDamage: number}
    if type(deltaSpeed) ~= "number" or type(speedBefore) ~= "number"
        or deltaSpeed ~= deltaSpeed or speedBefore ~= speedBefore
        or deltaSpeed < 0 or speedBefore < 0
        or deltaSpeed > 5000 or speedBefore > 5000 then
        return {damage = 0, occupantDamage = 0}
    end
    if not grounded or deltaSpeed < 15 or speedBefore < 18 then
        return {damage = 0, occupantDamage = 0}
    end
    local severity = math.min(1, (deltaSpeed - 15) / 115)
    return {
        damage = math.floor(severity * 85 + 0.5),
        occupantDamage = if playerOccupied then math.floor(severity * 35 + 0.5) else 0,
    }
end

function Damage.DriveFactor(health: number): number
    if type(health) ~= "number" or health ~= health then return 0 end
    if health <= 0 then return 0 end
    if health <= 20 then return 0.3 end
    return math.clamp(0.3 + health / 140, 0.3, 1)
end

function Damage.Status(health: number): string
    if health <= 0 then return "wrecked" end
    if health <= 20 then return "critical" end
    if health <= 55 then return "damaged" end
    return "operational"
end

return table.freeze(Damage)
