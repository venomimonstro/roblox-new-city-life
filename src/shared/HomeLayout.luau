--!strict
-- Server-session residential plots. All players get distinct active home plots.
-- Preferred address is deterministic from UserId. Collisions are resolved only
-- for players in the same server; global land ownership needs a separate backend.
local Layout = {}
Layout.Capacity = 48

function Layout.Preferred(userId: number): number
    -- Multi-client Studio creates test users with negative UserIds.
    -- This validation must work for both production IDs and simulated clients.
    assert(type(userId) == "number" and userId == userId and userId % 1 == 0
        and math.abs(userId) < 9007199254740992, "Invalid Roblox user id")
    return userId % Layout.Capacity
end

function Layout.Plot(slot: number): any?
    if type(slot) ~= "number" or slot % 1 ~= 0
        or slot < 0 or slot >= Layout.Capacity then return nil end
    local row = math.floor(slot / 24)
    local index = slot % 24
    -- Avoid north-south roads at every x=100*n; each house/garage stays
    -- in the middle of a 100-stud block with 10+ studs of road clearance.
    local side = if index < 12 then 1 else -1
    local within = index % 12
    local x = (math.floor(within / 2) * 100
        + (if within % 2 == 0 then 31 else 67)) * side
    local sign = if row == 0 then -1 else 1
    return {
        slot = slot,
        house = Vector3.new(x, 0, sign * 258),
        garage = Vector3.new(x, 0, sign * 229),
        car = Vector3.new(x, 3.4, sign * 226),
        respawn = Vector3.new(x + 10, 3.5, sign * 245), -- clear of house wall and garage eaves
        heading = if row == 0 then math.pi else 0,
        district = if row == 0 then "South Residential" else "North Residential",
    }
end

return table.freeze(Layout)
