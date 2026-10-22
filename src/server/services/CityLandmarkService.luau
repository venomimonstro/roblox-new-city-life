--!strict
-- Seven distinct nonblocking civic landmarks. Art geometry is decorative only:
-- street, building, home and NPC services remain the sole collision owners.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Landmarks = {}

local themes = {
    downtown = {"Civic Square", Color3.fromRGB(53, 124, 155)},
    luxury = {"Arts Promenade", Color3.fromRGB(177, 153, 109)},
    oldtown = {"Historic Plaza", Color3.fromRGB(160, 107, 81)},
    port = {"Harbor Exchange", Color3.fromRGB(74, 140, 151)},
    village = {"Community Gardens", Color3.fromRGB(84, 151, 103)},
    mountains = {"Trail Center", Color3.fromRGB(106, 131, 96)},
    coast = {"Seaside Walk", Color3.fromRGB(80, 158, 181)},
}

local function detail(parent: Instance, name: string, size: Vector3,
    position: Vector3, color: Color3, material: Enum.Material): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = CFrame.new(position)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Color = color
    part.Material = material
    part.Parent = parent
    return part
end

local function label(parent: Instance, pos: Vector3, name: string, tint: Color3)
    local board = detail(parent, "LandmarkSign", Vector3.new(18, 4, 0.3),
        pos, tint, Enum.Material.Metal)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.CanvasSize = Vector2.new(540, 120)
    gui.LightInfluence = 0
    gui.Parent = board
    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(1, 1)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Text = name
    title.TextColor3 = Color3.fromRGB(244, 240, 225)
    title.Parent = gui
end

function Landmarks.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(not world:FindFirstChild("CityLandmarks"), "Landmarks already initialized")
    local root = Instance.new("Folder")
    root.Name = "CityLandmarks"
    root.Parent = world
    for index, district in Districts do
        local theme = themes[district.id]
        assert(theme, "Missing district landmark theme: " .. district.id)
        local zone = Instance.new("Model")
        zone.Name = district.id .. "_Landmark"
        zone:SetAttribute("DistrictId", district.id)
        zone.Parent = root
        -- Center on the district's nearest four-way junction. No part may
        -- collide with the car, character, garage or wheel-ground raycasts.
        local x = math.round(district.x / 100) * 100
        local z = math.round(district.z / 100) * 100
        local tint = theme[2] :: Color3
        label(zone, Vector3.new(x + 31, 7.5, z + 31), theme[1] :: string, tint)
        for n = 1, 4 do
            local side = if n % 2 == 0 then 1 else -1
            local dx = side * (24 + n * 1.2)
            local dz = (if n <= 2 then -1 else 1) * 28
            local location = Vector3.new(x + dx, 0.05, z + dz)
            local planter = detail(zone, "Planter", Vector3.new(6, 1.3, 3),
                location, Color3.fromRGB(127, 119, 102), Enum.Material.Concrete)
            planter:SetAttribute("DecorativeOnly", true)
            local green = detail(zone, "PlanterShrub", Vector3.new(4, 2.7, 2.8),
                location + Vector3.new(0, 1.7, 0),
                Color3.fromRGB(55 + index * 6, 116, 71), Enum.Material.Grass)
            green.Shape = Enum.PartType.Ball
            detail(zone, "RestBenchSeat", Vector3.new(5, 0.35, 1.8),
                location + Vector3.new(8 * side, 1.2, 0),
                Color3.fromRGB(143, 112, 82), Enum.Material.WoodPlanks)
            for _, offset in {-1.6, 1.6} do
                detail(zone, "BenchLeg", Vector3.new(0.25, 1.1, 1.4),
                    location + Vector3.new(8 * side + offset, 0.5, 0),
                    Color3.fromRGB(78, 85, 90), Enum.Material.Metal)
            end
        end
        -- Decorative fountain: no water Terrain or solid basin on the street.
        local fountain = detail(zone, "PublicArtBase", Vector3.new(7, 0.4, 7),
            Vector3.new(x + 35, 0.1, z - 35), tint, Enum.Material.Concrete)
        fountain.Shape = Enum.PartType.Cylinder
        local art = detail(zone, "PublicArt", Vector3.new(1.6, 6, 1.6),
            Vector3.new(x + 35, 3, z - 35),
            Color3.fromRGB(200, 191, 160), Enum.Material.Metal)
        art.Shape = Enum.PartType.Cylinder
    end
    print("[StreetCity] Seven neighborhood civic landmarks ready")
end

return Landmarks
