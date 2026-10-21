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

    part(root, "Ground", Vector3.new(850, 2, 850), Vector3.new(0, -2, 0), grass, Enum.Material.Grass)
    local roadFolder = Instance.new("Folder")
    roadFolder.Name = "Roads"
    roadFolder.Parent = root

    for i = -2, 2 do
        local n = i * Config.World.RoadSpacing
        part(roadFolder, "NorthSouth_" .. tostring(i), Vector3.new(Config.World.RoadWidth, 0.35, 575), Vector3.new(n, -0.77, 0), road, Enum.Material.Asphalt)
        part(roadFolder, "EastWest_" .. tostring(i), Vector3.new(575, 0.36, Config.World.RoadWidth), Vector3.new(0, -0.76, n), road, Enum.Material.Asphalt)
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
