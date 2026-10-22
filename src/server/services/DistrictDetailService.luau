--!strict
-- Businesses and ground-level props only.
-- CityArchitecture owns windows/roofs; StreetDetailService owns every road,
-- sidewalk, crossing and lamp. Do not duplicate those collision surfaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Decor = {}
local SHOPS = {"MARKET", "CAFE", "GARAGE", "OFFICE", "STUDIO", "HOTEL"}

local function shape(parent: Instance, name: string, size: Vector3,
    frame: CFrame, color: Color3, material: Enum.Material): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = frame
    p.Color = color
    p.Material = material
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Parent = parent
    return p
end

local function storefront(parent: Instance, building: BasePart, index: number)
    local bottom = building.Position.Y - building.Size.Y / 2
    local front = building.Position.Z - building.Size.Z / 2 - 0.4
    local theme = if index % 3 == 0 then Color3.fromRGB(47, 91, 89)
        elseif index % 3 == 1 then Color3.fromRGB(134, 75, 72)
        else Color3.fromRGB(74, 85, 124)
    local board = shape(parent, "BusinessSign", Vector3.new(11, 1.65, 0.2),
        CFrame.new(building.Position.X, bottom + 8.2, front),
        theme, Enum.Material.Metal)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "BusinessSignText"
    gui.Face = Enum.NormalId.Front
    gui.CanvasSize = Vector2.new(400, 70)
    gui.LightInfluence = 0.35
    gui.Parent = board
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = SHOPS[index % #SHOPS + 1]
    label.TextColor3 = Color3.fromRGB(234, 232, 217)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = gui
    shape(parent, "BusinessAwning", Vector3.new(11, 0.25, 3.3),
        CFrame.new(building.Position.X, bottom + 6.95, front - 1.35),
        theme, Enum.Material.Fabric)
    for _, xOffset in {-7.5, 7.5} do
        -- Planters sit inside the building lot; completely decorative and
        -- cannot block roads, suspend cars or trap Roblox avatars.
        shape(parent, "Planter", Vector3.new(2.5, 1, 2.5),
            CFrame.new(building.Position.X + xOffset, bottom + 0.5, front - 2),
            Color3.fromRGB(104, 99, 87), Enum.Material.Concrete)
        local shrub = shape(parent, "Shrub", Vector3.new(2.3, 2.5, 2.3),
            CFrame.new(building.Position.X + xOffset, bottom + 2.1, front - 2),
            Color3.fromRGB(58, 121, 79), Enum.Material.Grass)
        shrub.Shape = Enum.PartType.Ball
    end
end

function Decor.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(world:FindFirstChild("DistrictDetails") == nil,
        "Duplicate district storefront pass")
    local districtRoot = world:WaitForChild("DistrictBlockouts")
    local details = Instance.new("Folder")
    details.Name = "DistrictDetails"
    details.Parent = world
    local count = 0
    for _, district in Districts do
        local zone = Instance.new("Folder")
        zone.Name = district.id
        zone.Parent = details
        local source = districtRoot:WaitForChild(district.id)
        local buildingIndex = 0
        for _, core in source:GetChildren() do
            if core:IsA("BasePart") and core.Name:match("^Building_") then
                buildingIndex += 1
                if buildingIndex % 2 == 0 then
                    storefront(zone, core, buildingIndex)
                    count += 1
                end
            end
        end
    end
    print("[StreetCity] Distinct storefronts added: " .. tostring(count)
        .. " (street collision authority remains StreetDetailService)")
end

return Decor
