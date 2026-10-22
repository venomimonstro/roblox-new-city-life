--!strict
-- Production map geometry acceptance. Samples real Roblox collision geometry;
-- decorations and vehicles are excluded so roads cannot pass on fake surfaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Homes = require(ReplicatedStorage.Shared:WaitForChild("HomeLayout"))
local Audit = {}

local function ground(x: number, z: number): RaycastResult?
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local vehicles = workspace:FindFirstChild("ActiveVehicles")
    if vehicles then params.FilterDescendantsInstances = {vehicles} end
    params.IgnoreWater = true
    return workspace:Raycast(Vector3.new(x, 22, z), Vector3.new(0, -70, 0), params)
end

local function drivable(x: number, z: number)
    local hit = ground(x, z)
    assert(hit ~= nil, "[StreetCity Surface] No collision ground at " .. x .. "," .. z)
    assert(hit.Normal.Y > 0.92,
        "[StreetCity Surface] Dangerous slope or building at " .. x .. "," .. z)
    assert(hit.Material == Enum.Material.Asphalt,
        "[StreetCity Surface] Asphalt missing or road obstructed at " .. x .. "," .. z
        .. " (found " .. tostring(hit.Material) .. ")")
end

function Audit.Validate()
    local checked = 0
    -- Longitudinal and perpendicular road continuity, including panel seams.
    for axis = -1700, 1700, 100 do
        for _, crossing in {-1795, -1350, -905, -900, -895, -450, -5,
            0, 5, 450, 895, 900, 905, 1350, 1795} do
            drivable(axis, crossing)
            drivable(crossing, axis)
            checked += 2
        end
    end
    -- Every regional center is connected to the grid without road gaps.
    for _, zone in Districts do
        local x = math.round(zone.x / 100) * 100
        local z = math.round(zone.z / 100) * 100
        for _, d in {-200, -100, 0, 100, 200} do
            drivable(x + d, z)
            drivable(x, z + d)
            checked += 2
        end
    end
    -- Personal car recovery and home respawn must have actual collision floors.
    for slot = 0, Homes.Capacity - 1 do
        local plot = Homes.Plot(slot)
        assert(plot, "[StreetCity Surface] Unallocated home")
        local carFloor = ground(plot.car.X, plot.car.Z)
        assert(carFloor and carFloor.Normal.Y > 0.7,
            "[StreetCity Surface] Missing private garage floor: " .. slot)
        local respawnFloor = ground(plot.respawn.X, plot.respawn.Z)
        assert(respawnFloor and respawnFloor.Normal.Y > 0.7,
            "[StreetCity Surface] Player respawns above void: " .. slot)
        checked += 2
    end
    print("[StreetCity Surface] PASS " .. tostring(checked)
        .. " road, neighborhood, garage and home spawn raycasts")
end

return table.freeze(Audit)
