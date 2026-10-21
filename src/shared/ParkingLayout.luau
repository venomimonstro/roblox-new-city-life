--!strict
-- Deterministic temporary street parking; positions intentionally outside race course.
local ParkingLayout = {Capacity = 48}

function ParkingLayout.Position(slot: number): Vector3?
    if type(slot) ~= "number" or slot % 1 ~= 0
        or slot < 0 or slot >= ParkingLayout.Capacity then return nil end
    local row = math.floor(slot / 24)
    local index = slot % 24
    local sign = if index % 2 == 0 then 1 else -1
    local x = (math.floor(index / 2) + 1) * 18 * sign
    return Vector3.new(x, 4, if row == 0 then -200 else 200)
end

return table.freeze(ParkingLayout)
