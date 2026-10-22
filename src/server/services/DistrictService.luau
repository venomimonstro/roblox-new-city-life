--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DistrictConfig"))
local Architecture = require(script.Parent:WaitForChild("CityArchitecture"))
local DistrictService = {}

local function createPart(parent: Instance, name: string, size: Vector3, position: Vector3, material: Enum.Material, color: Color3)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Material = material
    p.Color = color
    p.Parent = parent
    return p
end

function DistrictService.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(world:FindFirstChild("DistrictBlockouts") == nil, "Duplicate world generation")
    local root = Instance.new("Folder")
    root.Name = "DistrictBlockouts"
    root.Parent = world
    local asphalt = Color3.fromRGB(53, 56, 62)
    for index, district in Districts do
        local zone = Instance.new("Folder")
        zone.Name = district.id
        zone.Parent = root
        zone:SetAttribute("DistrictId", district.id)
        local rng = Random.new(24021 + index * 17)
        local x, z = district.x, district.z
        createPart(zone, "Ground", Vector3.new(490, 2, 490), Vector3.new(x, -2, z),
            if district.id == "coast" then Enum.Material.Sand else Enum.Material.Grass,
            if district.id == "coast" then Color3.fromRGB(225, 205, 157) else Color3.fromRGB(85, 136, 84))
        for n = 1, district.buildingCount do
            local height = rng:NextInteger(14, if district.id == "downtown" then 95 else 38)
            local core = createPart(zone, "Building_" .. n, Vector3.new(30, height, 30),
                -- Roads are on 100-stud grid lines, width 25 studs.
                -- Center every building halfway BETWEEN grid lines. The old
                -- +25 offset intersected road collision by ~2.5 studs.
                Vector3.new(math.floor(x / 100) * 100 + ((n - 1) % 4 - 1.5) * 100,
                    height / 2 - 1, math.floor(z / 100) * 100
                        + (math.floor((n - 1) / 4) - 1) * 100 + 50),
                Enum.Material.Concrete, Color3.fromRGB(130 + index * 8, 135, 148))
            Architecture.DecorateBuilding(zone, core, district.id, n)
        end
        -- WorldService owns ALL connected roads; no extra diagonal or
        -- off-grid connectors can clip district buildings.

    end
    print("[StreetCity] Seven district blockouts initialized")
end

return DistrictService
