--!strict
-- Server-session residential plots. All players get distinct active home plots.
-- Preferred address is deterministic from UserId. Collisions are resolved only
-- for players in the same server; global land ownership needs a separate backend.
local Layout = {}
Layout.Capacity = 48

function Layout.Preferred(userId: number): number
    assert(type(userId) == "number" and userId >= 0, "Invalid Roblox user id")
    return userId % Layout.Capacity
end

function Layout.Plot(slot: number): any?
    if type(slot) ~= "number" or slot % 1 ~= 0
        or slot < 0 or slot >= Layout.Capacity then return nil end
    local row = math.floor(slot / 24)
    local index = slot % 24
    local side = if index % 2 == 0 then 1 else -1
    local x = (math.floor(index / 2) + 1) * 18 * side
    local sign = if row == 0 then -1 else 1
    return {
        slot = slot,
        house = Vector3.new(x, 0, sign * 258),
        garage = Vector3.new(x, 0, sign * 229),
        car = Vector3.new(x, 3.4, sign * 226),
        respawn = Vector3.new(x + 7, 3.5, sign * 245),
        heading = if row == 0 then math.pi else 0,
        district = if row == 0 then "South Residential" else "North Residential",
    }
end

return table.freeze(Layout)
