--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DistrictConfig"))
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
            createPart(zone, "Building_" .. n, Vector3.new(30, height, 30),
                Vector3.new(x + ((n - 1) % 4 - 1.5) * 100 + 25,
                    height / 2 - 1, z + (math.floor((n - 1) / 4) - 1) * 100 + 25),
                Enum.Material.Concrete, Color3.fromRGB(130 + index * 8, 135, 148))
        end
        if district.id ~= "downtown" then
            createPart(root, district.id .. "_EW", Vector3.new(math.abs(x) + 30, 0.5, 24),
                Vector3.new(x / 2, -0.7, 0), Enum.Material.Asphalt, asphalt)
            createPart(root, district.id .. "_NS", Vector3.new(24, 0.5, math.abs(z) + 30),
                Vector3.new(x, -0.7, z / 2), Enum.Material.Asphalt, asphalt)
        end
    end
    print("[StreetCity] Seven district blockouts initialized")
end

return DistrictService
