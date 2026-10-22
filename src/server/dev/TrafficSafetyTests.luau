--!strict
-- Roblox Studio integration acceptance: real generated geometry + ambient AI.
-- Pure checks never mutate profile, charge credits, or destroy live cars.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Districts = require(Shared:WaitForChild("DistrictConfig"))
local Tests = {}

function Tests.Run()
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
    local folder = workspace:WaitForChild("ActiveVehicles")
    local citizens = root:WaitForChild("CityPedestrians")
    local uniqueSpawn = {}
    local carCount = 0
    local policeCount = 0
    for _, car in folder:GetChildren() do
        if car:IsA("Model") and car:GetAttribute("TrafficNPC") == true then
            carCount += 1
            local seat = car:FindFirstChild("DriverSeat")
            assert(seat and seat:IsA("VehicleSeat"),
                "Traffic car is missing a seat and can never be stolen")
            assert(car.PrimaryPart ~= nil,
                "Traffic car has no primary physics body")
            assert(car.PrimaryPart.Position.Y > -8,
                "Traffic spawned below the seamless terrain")
            assert(car:GetAttribute("OwnerUserId") == nil,
                "Civilian traffic car was accidentally assigned to a personal owner")
            local pos = car.PrimaryPart.Position
            local hash = math.floor(pos.X / 10) .. ":" .. math.floor(pos.Z / 10)
            assert(not uniqueSpawn[hash], "Traffic vehicles spawned inside one another")
            uniqueSpawn[hash] = true
            if car:GetAttribute("IsPolice") then policeCount += 1 end
        end
    end
    assert(carCount >= 14 and policeCount >= 3,
        "City requires civilian traffic across all districts and police patrols")
    local population = 0
    for _, npc in citizens:GetChildren() do
        if npc:IsA("Model") and npc:GetAttribute("Citizen") == true then
            assert(npc.PrimaryPart ~= nil,
                "Pedestrian cannot be considered by traffic yielding logic")
            assert(npc.PrimaryPart.Position.Y > -8,
                "Pedestrian created beneath walkable ground")
            population += 1
        end
    end
    assert(population >= #Districts * 4,
        "Seven districts must have local civilian populations")
    local terrain = workspace.Terrain
    local road = root:WaitForChild("Roads")
    local ray = RaycastParams.new()
    ray.IgnoreWater = true
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = {road, terrain}
    local samples = 0
    -- Selective road seam probes at the old 900-stud panel boundaries:
    -- a car must find actual asphalt at both sides of every seam.
    for _, x in {-1700, -900, 0, 900, 1700} do
        for _, z in {-1800, -1820, -900, -880, 0, 880, 900, 1800} do
            local hit = workspace:Raycast(Vector3.new(x, 18, z),
                Vector3.new(0, -45, 0), ray)
            assert(hit and hit.Material == Enum.Material.Asphalt
                and hit.Normal.Y >= 0.95,
                "Traversable city street is disconnected at " .. x .. " / " .. z)
            samples += 1
        end
    end
    print("[StreetCity] PASS traffic safety: " .. carCount .. " vehicles, "
        .. policeCount .. " police, " .. population .. " NPCs, "
        .. samples .. " real road seam probes")
end

return Tests
