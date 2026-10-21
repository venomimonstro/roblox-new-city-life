--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldService = {}
local WORLD_NAME = "StreetCityPrototypeWorld"

local function part(
    parent: Instance,
    name: string,
    size: Vector3,
    pos: Vector3,
    color: Color3,
    material: Enum.Material,
    collide: boolean?
): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
    p.Anchored = true
    p.CanCollide = if collide == nil then true else collide
    p.CanQuery = p.CanCollide -- Decorative ocean must not become raycast ground.
    p.Material = material
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

function WorldService.Start()
    if workspace:FindFirstChild(WORLD_NAME) then
        error("World already exists; refusing to duplicate geometry")
    end

    local root = Instance.new("Folder")
    root.Name = WORLD_NAME
    root.Parent = workspace
    local rng = Random.new(Config.World.Seed)
    local grass = Color3.fromRGB(72, 130, 75)
    local road = Color3.fromRGB(49, 52, 60)

    -- Seamless 3.6 km-stud terrain collision grid. Chunked FillBlock avoids
    -- oversized Parts and prevents falling into voids between far districts.
    local terrain = workspace.Terrain
    local chunk = 256
    local extent = 1792
    for x = -extent + chunk / 2, extent - chunk / 2, chunk do
        for z = -extent + chunk / 2, extent - chunk / 2, chunk do
            terrain:FillBlock(CFrame.new(x, -5, z),
                Vector3.new(chunk, 8, chunk), Enum.Material.Grass)
        end
    end
    part(root, "Ground", Vector3.new(850, 2, 850), Vector3.new(0, -2, 0), grass, Enum.Material.Grass)
    local roadFolder = Instance.new("Folder")
    roadFolder.Name = "Roads"
    roadFolder.Parent = root
    -- Connected asphalt across all seven district approaches. Road segment
    -- lengths remain under Roblox BasePart limits; 40-stud overlaps remove gaps.
    for i = -17, 17 do
        local n = i * Config.World.RoadSpacing
        for section = -2, 1 do
            local center = (section + 0.5) * 900
            local laneLength = 940
            part(roadFolder, "NorthSouth_" .. i .. "_" .. section,
                Vector3.new(Config.World.RoadWidth, 0.35, laneLength),
                Vector3.new(n, -0.77, center), road, Enum.Material.Asphalt)
            part(roadFolder, "EastWest_" .. i .. "_" .. section,
                Vector3.new(laneLength, 0.35, Config.World.RoadWidth),
                Vector3.new(center, -0.76, n), road, Enum.Material.Asphalt)
        end
    end

    -- DistrictService is the sole authority for all district buildings,
    -- including downtown. The former WorldService buildings duplicated
    -- downtown meshes/colliders at the exact same grid coordinates.
    local buildings = Instance.new("Folder")
    buildings.Name = "Buildings"
    buildings.Parent = root

    -- Coastal and hillside silhouettes: decorative placeholders, not final districts.
    part(root, "Beach", Vector3.new(850, 0.6, 125), Vector3.new(0, -0.45, 462), Color3.fromRGB(216, 195, 139), Enum.Material.Sand)
    part(root, "Ocean", Vector3.new(1300, 0.2, 350), Vector3.new(0, -0.65, 694), Color3.fromRGB(42, 134, 180), Enum.Material.Glass, false)
    for i = 1, 6 do
        local hill = part(root, "Hill_" .. i, Vector3.new(85, rng:NextInteger(25, 95), 90),
            Vector3.new(-355 + (i - 1) * 130, 5, -340),
            Color3.fromRGB(63, 113, 76), Enum.Material.Grass)
        hill.Shape = Enum.PartType.Ball
        hill.CanCollide = false
        hill.CanQuery = false -- terrain scenery must never close a driving lane
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "PlayerSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(17, 0, 17)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Color = Color3.fromRGB(71, 180, 118)
    spawn.Material = Enum.Material.Neon
    spawn.Parent = root

    Lighting.ClockTime = 17
    Lighting.Brightness = 2
    print("[StreetCity] Deterministic prototype world generated, seed:", Config.World.Seed)
end

return WorldService
