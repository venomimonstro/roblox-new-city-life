--!strict
-- Surface dressing over authoritative roads and CityArchitecture facades.
-- DistrictService owns building collision; this module must NOT duplicate
-- facade windows or create phantom walls in driveable lanes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local Decor = {}

local SIGNS = {"MARKET", "CAFE", "AUTO REPAIR", "OFFICE", "STUDIO", "HOTEL"}
local INK = Color3.fromRGB(219, 211, 180)
local ZEBRA = Color3.fromRGB(231, 235, 230)
local PAVEMENT = Color3.fromRGB(147, 157, 160)

local function piece(parent: Instance, name: string, size: Vector3,
    frame: CFrame, color: Color3, material: Enum.Material, solid: boolean?): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = frame
    p.Anchored = true
    p.CanCollide = solid == true
    p.CanQuery = solid == true
    p.CanTouch = false
    p.CastShadow = solid == true
    p.Material = material
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function shopSign(parent: Instance, building: BasePart, id: number)
    local y = building.Position.Y - building.Size.Y / 2 + 8
    local z = building.Position.Z - building.Size.Z / 2 - 0.3
    local board = piece(parent, "StorefrontSign", Vector3.new(11, 1.5, 0.25),
        CFrame.new(building.Position.X, y, z),
        Color3.fromRGB(45, 82, 94), Enum.Material.Metal)
    local screen = Instance.new("SurfaceGui")
    screen.Name = "StreetBusinessSign"
    screen.Face = Enum.NormalId.Front
    screen.LightInfluence = 0.5
    screen.CanvasSize = Vector2.new(440, 80)
    screen.Parent = board
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = SIGNS[(id - 1) % #SIGNS + 1]
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(231, 236, 232)
    label.Parent = screen
end

local function streetLight(parent: Instance, x: number, z: number, number: number)
    piece(parent, "LightPole", Vector3.new(0.34, 11, 0.34),
        CFrame.new(x, 4.5, z), Color3.fromRGB(70, 82, 86), Enum.Material.Metal)
    piece(parent, "LightArm", Vector3.new(3, 0.24, 0.24),
        CFrame.new(x - 1.3, 9.88, z), Color3.fromRGB(70, 82, 86),
        Enum.Material.Metal)
    local lamp = piece(parent, "LightFixture", Vector3.new(1.6, 0.28, 0.9),
        CFrame.new(x - 2.5, 9.75, z),
        Color3.fromRGB(248, 218, 164), Enum.Material.Neon)
    -- Only every fourth post emits a dynamic PointLight.
    if number % 4 == 0 then
        local bulb = Instance.new("PointLight")
        bulb.Range = 24
        bulb.Brightness = 0.8
        bulb.Shadows = false
        bulb.Color = Color3.fromRGB(247, 218, 168)
        bulb.Parent = lamp
    end
end

local function streetBlock(parent: Instance, originX: number, originZ: number)
    local width = Config.World.RoadWidth
    local sidewalkOffset = width / 2 + 3.6
    local x = originX + 50
    local z = originZ + 50
    for _, side in {-1, 1} do
        -- 66-stud sidewalks stop 17 studs short of the next crossing.
        -- This preserves a clear crossing through every perpendicular road.
        piece(parent, "WalkwayNorthSouth",
            Vector3.new(7, 0.14, 66),
            CFrame.new(originX + side * sidewalkOffset, -0.43, z),
            PAVEMENT, Enum.Material.Concrete, true)
        piece(parent, "WalkwayEastWest",
            Vector3.new(66, 0.14, 7),
            CFrame.new(x, -0.43, originZ + side * sidewalkOffset),
            PAVEMENT, Enum.Material.Concrete, true)
    end
    for _, m in {-1, 1} do
        piece(parent, "BrokenRoadLineNS", Vector3.new(0.25, 0.04, 7),
            CFrame.new(originX, -0.54, z + m * 16),
            INK, Enum.Material.SmoothPlastic)
        piece(parent, "BrokenRoadLineEW", Vector3.new(7, 0.04, 0.25),
            CFrame.new(x + m * 16, -0.54, originZ),
            INK, Enum.Material.SmoothPlastic)
    end
end

function Decor.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(not world:FindFirstChild("DistrictDetails"), "Street dressing already exists")
    local districts = world:WaitForChild("DistrictBlockouts")
    local details = Instance.new("Folder")
    details.Name = "DistrictDetails"
    details.Parent = world
    local facadeSigns, completedBlocks = 0, 0
    for number, district in Districts do
        local area = districts:WaitForChild(district.id)
        local zone = Instance.new("Folder")
        zone.Name = district.id
        zone.Parent = details
        for _, building in area:GetChildren() do
            if building:IsA("BasePart") and building.Name:match("^Building_") then
                if facadeSigns % 2 == 0 then
                    shopSign(zone, building, facadeSigns + 1)
                end
                facadeSigns += 1
            end
        end
        local ox = math.floor(district.x / 100 + 0.5) * 100
        local oz = math.floor(district.z / 100 + 0.5) * 100
        for dx = -2, 1 do
            for dz = -2, 1 do
                streetBlock(zone, ox + dx * 100, oz + dz * 100)
                completedBlocks += 1
            end
        end
        for n = 1, 3 do
            local atX = ox + (n - 2) * 100
            for stripe = -3, 3 do
                piece(zone, "ZebraCrossing", Vector3.new(1.7, 0.045, 5.0),
                    CFrame.new(atX + stripe * 2.8, -0.53, oz + 17),
                    ZEBRA, Enum.Material.SmoothPlastic)
            end
        end
        for n = 1, 7 do
            streetLight(zone, ox + (n - 4) * 100 + 20,
                oz + (if n % 2 == 0 then 20 else -20),
                (number - 1) * 7 + n)
        end
    end
    print("[StreetCity] Street detail: " .. tostring(completedBlocks)
        .. " blocks, streetlights, safe sidewalks and detailed crossings")
end

return Decor
