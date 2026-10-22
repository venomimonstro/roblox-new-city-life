--!strict
-- Roblox Studio world acceptance: ground seams, walkable home doors, road
-- collisions, safe garages and bounded decorative part counts.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("HomeLayout"))
local Districts = require(Shared:WaitForChild("DistrictConfig"))
local Tests = {}
local function surfaceAt(x: number, z: number): RaycastResult?
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local vehicles = workspace:FindFirstChild("ActiveVehicles")
    if vehicles then params.FilterDescendantsInstances = {vehicles} end
    params.IgnoreWater = true
    return workspace:Raycast(Vector3.new(x, 18, z), Vector3.new(0, -45, 0), params)
end
function Tests.Run()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local streets = world:FindFirstChild("StreetEnvironment")
    assert(streets and streets:IsA("Folder"), "Street environment missing")
    local walks = streets:FindFirstChild("Sidewalks")
    local paint = streets:FindFirstChild("LanePaint")
    local crossings = streets:FindFirstChild("Crosswalks")
    local lamps = streets:FindFirstChild("Streetlights")
    assert(walks and #walks:GetChildren() == 560, "Broken sidewalk road segments")
    assert(paint and #paint:GetChildren() == 560, "Incomplete lane paint sections")
    assert(crossings and #crossings:GetChildren() >= 190, "No crossings for walkers")
    assert(lamps and #lamps:GetChildren() == 56, "Street light posts and heads missing")
    for _, p in paint:GetChildren() do
        assert(p:IsA("BasePart") and not p.CanCollide and not p.CanQuery,
            "Lane paint must not act as a suspension or wheel obstacle")
    end

    -- Every road segment boundary must have a drivable hit, including the
    -- invisible seams between 940-stud asphalt panels.
    for _, x in {-1700, -900, -100, 0, 100, 900, 1700} do
        for _, z in {-1800, -900, -10, 0, 10, 900, 1800} do
            local result = surfaceAt(x, z)
            assert(result ~= nil and result.Normal.Y > 0.95,
                "No solid drivable surface at road sample: " .. x .. ", " .. z)
            assert(result.Material == Enum.Material.Asphalt,
                "Road sample hit wrong material: " .. x .. ", " .. z)
        end
    end
    -- Last asphalt endpoint must have surrounding terrain rather than void.
    for _, signX in {-1, 1} do
        for _, signZ in {-1, 1} do
            local result = surfaceAt(signX * 1980, signZ * 1980)
            assert(result and result.Normal.Y > 0.9,
                "Outer playable area has a fatal terrain gap")
        end
    end

    local homes = world:FindFirstChild("ResidentialHomes")
    assert(homes and #homes:GetChildren() == Layout.Capacity, "Home count mismatch")
    for slot = 0, Layout.Capacity - 1 do
        local plot = Layout.Plot(slot)
        local home = homes:FindFirstChild("Home_" .. tostring(slot + 1))
        assert(plot and home and home:IsA("Model"), "Missing house plot")
        local anchor = home:FindFirstChild("House")
        assert(anchor and anchor:IsA("BasePart") and not anchor.CanCollide,
            "Homes must not be inaccessible solid cubes")
        local frontWings, sides = 0, 0
        for _, child in home:GetChildren() do
            if child.Name == "HouseFrontWing" then frontWings += 1 end
            if child.Name == "HouseSideWall" then sides += 1 end
        end
        assert(frontWings == 2 and sides == 2, "House shell/door opening invalid")
        local floor = home:FindFirstChild("HouseFloor")
        local garage = home:FindFirstChild("GarageFloor")
        local roof = home:FindFirstChild("GarageRoof")
        assert(floor and floor:IsA("BasePart") and floor.CanCollide,
            "Home walkable floor missing")
        assert(garage and garage:IsA("BasePart") and garage.CanCollide
            and roof and roof:IsA("BasePart") and roof.CanCollide,
            "Garage is not physically usable")
        local relative = plot.car - plot.garage
        assert(math.abs(relative.X) < garage.Size.X / 2 - 2.2
            and math.abs(relative.Z) < garage.Size.Z / 2 - 5.0,
            "Owned car does not fit its garage footprint")
        local front = if slot < 24 then 1 else -1
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Include
        ray.FilterDescendantsInstances = {home}
        local door = workspace:Raycast(
            plot.house + Vector3.new(0, 3.5, front * 12),
            Vector3.new(0, 0, -front * 9), ray)
        assert(door and door.Instance and door.Instance.Name == "FrontDoor"
            and door.Instance:FindFirstChild("FrontDoorPrompt"),
            "House door is blocked by geometry other than its usable hinged door")
    end
    -- All seven neighborhood fleets must be present on connected asphalt,
    -- never created on roofs or terrain outside the road grid.
    local active = workspace:FindFirstChild("ActiveVehicles")
    assert(active and active:IsA("Folder"), "Missing physical traffic fleet")
    local civilian, police = 0, 0
    local fleets: {[string]: number} = {}
    for _, model in active:GetChildren() do
        if model:IsA("Model") and model:GetAttribute("TrafficNPC") == true then
            local chassis = model:FindFirstChild("Chassis")
            assert(chassis and chassis:IsA("BasePart"), "NPC vehicle lacks chassis")
            local rx = math.abs(chassis.Position.X
                - math.round(chassis.Position.X / 100) * 100)
            local rz = math.abs(chassis.Position.Z
                - math.round(chassis.Position.Z / 100) * 100)
            assert(rx < 6 or rz < 6,
                "Traffic spawned off the connected 100-stud road grid")
            local nearest = 100000
            local best = ""
            for _, district in Districts do
                local dx = chassis.Position.X - district.x
                local dz = chassis.Position.Z - district.z
                local distance = dx * dx + dz * dz
                if distance < nearest then
                    nearest = distance
                    best = district.id
                end
            end
            fleets[best] = (fleets[best] or 0) + 1
            if model:GetAttribute("IsPolice") then police += 1
            else civilian += 1 end
        end
    end
    assert(civilian >= 14 and police >= 3,
        "World regressed to downtown-only traffic or lost police cars")
    for _, district in Districts do
        assert((fleets[district.id] or 0) >= 2,
            "No autonomous traffic in district " .. district.id)
    end

    local areas = world:FindFirstChild("DistrictBlockouts")
    for _, district in Districts do
        local area = areas and areas:FindFirstChild(district.id)
        assert(area and area:IsA("Folder"), "Missing district " .. district.id)
        for _, object in area:GetChildren() do
            if object:IsA("BasePart") and object.Name:match("^Building_") then
                local x = object.Position.X
                local z = object.Position.Z
                local left = math.abs(x - math.round(x / 100) * 100)
                local front = math.abs(z - math.round(z / 100) * 100)
                assert(left >= object.Size.X / 2 + 12.5
                    and front >= object.Size.Z / 2 + 12.5,
                    "Building blocks a street lane: " .. object.Name)
            end
        end
    end
    print("[StreetCity] PASS: 49 drivable road samples, 48 walkable houses,"
        .. " terrain beyond streets, cosmetic mark exclusions and district clearances")
end
return Tests
