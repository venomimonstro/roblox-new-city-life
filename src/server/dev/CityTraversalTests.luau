--!strict
-- City-level acceptance executed ONLY from Roblox Studio; unlike model-based
-- tests this actually raycasts the generated world and inspects physical Parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("HomeLayout"))
local Districts = require(Shared:WaitForChild("DistrictConfig"))
local Config = require(Shared:WaitForChild("Config"))
local Tests = {}

local function nearestRoadAxis(coord: number): number
    local spacing = Config.World.RoadSpacing
    return math.abs(coord - math.round(coord / spacing) * spacing)
end

function Tests.Run()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local roads = world:WaitForChild("Roads")
    local roadLength = 940
    local inspected = 0
    local lastEnd = nil
    for i = -17, 17 do
        lastEnd = nil
        for section = -2, 1 do
            local suffix = tostring(i) .. "_" .. tostring(section)
            local north = roads:FindFirstChild("NorthSouth_" .. suffix)
            local east = roads:FindFirstChild("EastWest_" .. suffix)
            assert(north and north:IsA("BasePart") and north.Anchored
                and north.CanCollide and north.CanQuery and north.Material == Enum.Material.Asphalt,
                "Missing asphalt north/south road " .. suffix)
            assert(east and east:IsA("BasePart") and east.Anchored
                and east.CanCollide and east.CanQuery and east.Material == Enum.Material.Asphalt,
                "Missing asphalt east/west road " .. suffix)
            assert(north.Size.Z >= roadLength and east.Size.X >= roadLength,
                "Road connector is too short " .. suffix)
            local left = north.Position.Z - north.Size.Z * 0.5
            local right = north.Position.Z + north.Size.Z * 0.5
            if lastEnd then
                assert(left <= lastEnd + 0.01,
                    "Street has a physical seam at section " .. suffix)
            end
            lastEnd = right
            inspected += 2
        end
        assert(lastEnd and lastEnd >= 1800, "Road terminates before playable district")
    end
    assert(inspected == 280, "Incorrect number of contiguous asphalt segments")

    local rayParams = RaycastParams.new()
    rayParams.IgnoreWater = true
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local vehicles = workspace:FindFirstChild("ActiveVehicles")
    rayParams.FilterDescendantsInstances = if vehicles then {vehicles} else {}
    local intersections = 0
    -- Every fourth junction, including outer districts and residential streets.
    for x = -1600, 1600, 200 do
        for z = -1600, 1600, 200 do
            local hit = workspace:Raycast(Vector3.new(x, 30, z),
                Vector3.new(0, -80, 0), rayParams)
            assert(hit and hit.Instance and hit.Instance.CanCollide
                and hit.Material == Enum.Material.Asphalt,
                "Road collision missing at " .. x .. "," .. z)
            intersections += 1
        end
    end

    local homes = world:WaitForChild("ResidentialHomes")
    assert(#homes:GetChildren() == Layout.Capacity, "Incomplete residential plots")
    local inspectedHomes = 0
    for slot = 0, Layout.Capacity - 1 do
        local plot = Layout.Plot(slot)
        assert(plot, "Missing residential plot " .. slot)
        local home = homes:FindFirstChild("Home_" .. tostring(slot + 1))
        assert(home and home:IsA("Model"), "Missing owner home")
        local anchor = home:FindFirstChild("House")
        assert(anchor and anchor:IsA("BasePart") and not anchor.CanCollide,
            "Walkable home has an invisible solid cube blocking its entrance")
        local door = home:FindFirstChild("FrontDoor", true)
        local ceiling = home:FindFirstChild("HouseCeiling")
        assert(door and door:IsA("BasePart") and door.CanCollide
            and door:FindFirstChild("FrontDoorPrompt"),
            "Home must have a real opening door")
        assert(ceiling and ceiling:IsA("BasePart") and ceiling.CanCollide,
            "Home roof lets player fall into empty geometry")
        assert(home:FindFirstChild("GarageRoof"), "Missing protected garage")
        assert(nearestRoadAxis(plot.house.X) > Config.World.RoadWidth / 2 + 9,
            "House side intersects driving corridor")
        assert(nearestRoadAxis(plot.garage.Z) > Config.World.RoadWidth / 2 + 14,
            "Garage blocks east-west driving corridor")
        assert(math.abs(plot.respawn.X - plot.house.X) >= 9,
            "Character may be born embedded in exterior wall")
        local ray = workspace:Raycast(plot.car + Vector3.new(0, 3, 0),
            Vector3.new(0, -14, 0), rayParams)
        assert(ray and ray.Instance and ray.Instance.Name == "GarageFloor",
            "Car spawn is not above its OWN physical garage floor")
        inspectedHomes += 1
    end

    local blocks = world:WaitForChild("DistrictBlockouts")
    local houseCount = 0
    for _, district in Districts do
        local districtFolder = blocks:FindFirstChild(district.id)
        assert(districtFolder, "District missing: " .. district.id)
        for _, core in districtFolder:GetChildren() do
            if core:IsA("BasePart") and core.Name:match("^Building_") then
                assert(core.CanCollide and core.CanQuery,
                    "Building collision shell absent " .. district.id)
                assert(nearestRoadAxis(core.Position.X)
                    >= core.Size.X / 2 + Config.World.RoadWidth / 2,
                    "Building hits north-south road " .. district.id)
                assert(nearestRoadAxis(core.Position.Z)
                    >= core.Size.Z / 2 + Config.World.RoadWidth / 2,
                    "Building hits east-west road " .. district.id)
                local facade = districtFolder:FindFirstChild("Facade_" .. core.Name)
                assert(facade and facade:IsA("Model"),
                    "Building has no windows/roof/facade " .. district.id)
                for _, child in facade:GetDescendants() do
                    if child:IsA("BasePart") then
                        assert(not child.CanCollide and not child.CanQuery,
                            "Art detail makes an invisible vehicle collision obstacle")
                    end
                end
                houseCount += 1
            end
        end
    end
    assert(houseCount >= 55, "City facade population incomplete")

    local streets = world:WaitForChild("StreetEnvironment")
    local sidewalks = streets:FindFirstChild("Sidewalks")
    local paint = streets:FindFirstChild("LanePaint")
    assert(sidewalks and paint and #sidewalks:GetChildren() >= 560,
        "Continuous city-wide sidewalks missing")
    for _, line in paint:GetChildren() do
        assert(line:IsA("BasePart") and not line.CanCollide
            and not line.CanQuery, "Lane paint must not affect vehicle suspension")
    end
    local worldLimits = world:FindFirstChild("WorldLimits")
    assert(worldLimits and #worldLimits:GetChildren() == 4,
        "Players can escape the terrain border and fall forever")
    local ocean = world:FindFirstChild("Ocean")
    assert(ocean and ocean:IsA("BasePart") and not ocean.CanCollide
        and not ocean.CanQuery, "Water graphic can obstruct city driving")
    local seaParams = RaycastParams.new()
    seaParams.IgnoreWater = false
    local water = workspace:Raycast(Vector3.new(0, 15, 2170),
        Vector3.new(0, -45, 0), seaParams)
    assert(water and water.Material == Enum.Material.Water,
        "Coastline must be swim-capable Terrain water, not a painted sheet")
    print("[StreetCity] PASS: " .. inspected .. " connected asphalt sections, "
        .. intersections .. " live wheel-ground probes, " .. inspectedHomes
        .. " walkable home spawns and " .. houseCount .. " detailed buildings")
end

return Tests
