--!strict
-- Street hierarchy: real collision-safe sidewalks, lane paint, crossings and
-- selective lamps. All art details either sit outside carriageways or have no
-- collision/query; vehicle suspension never sees decorative geometry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Streets = {}

local function make(parent: Instance, name: string, size: Vector3, pos: Vector3,
    color: Color3, material: Enum.Material, solid: boolean): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
    p.Color = color
    p.Material = material
    p.Anchored = true
    p.CanCollide = solid
    p.CanQuery = solid
    p.CanTouch = false
    p.CastShadow = solid
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

function Streets.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(not world:FindFirstChild("StreetEnvironment"), "Street details already exist")
    local root = Instance.new("Folder")
    root.Name = "StreetEnvironment"
    root.Parent = world
    local sidewalks = Instance.new("Folder")
    sidewalks.Name = "Sidewalks"
    sidewalks.Parent = root
    local paint = Instance.new("Folder")
    paint.Name = "LanePaint"
    paint.Parent = root
    local width = Config.World.RoadWidth
    local spacing = Config.World.RoadSpacing
    local curbOffset = width / 2 + 3.6
    local concrete = Color3.fromRGB(164, 165, 159)
    local yellow = Color3.fromRGB(224, 192, 105)
    local sidewalkCount, paintCount = 0, 0
    -- Every segment overlaps the next by 40 studs. All sidewalk tops are
    -- at -0.90, below the -0.595 asphalt top: no seams or curb to hit.
    for i = -17, 17 do
        local axis = i * spacing
        for section = -2, 1 do
            local center = (section + 0.5) * 900
            for _, side in {-1, 1} do
                make(sidewalks, "Walk_NS", Vector3.new(7.0, 0.42, 940),
                    Vector3.new(axis + side * curbOffset, -1.11, center),
                    concrete, Enum.Material.Concrete, true)
                make(sidewalks, "Walk_EW", Vector3.new(940, 0.42, 7.0),
                    Vector3.new(center, -1.11, axis + side * curbOffset),
                    concrete, Enum.Material.Concrete, true)
                sidewalkCount += 2
            end
            -- Longitudinal double yellow road stripe. No client-side
            -- raycast/physics collisions and no z-fighting with asphalt.
            for _, lane in {-0.32, 0.32} do
                make(paint, "DoubleYellow_NS", Vector3.new(0.18, 0.035, 940),
                    Vector3.new(axis + lane, -0.569, center),
                    yellow, Enum.Material.SmoothPlastic, false)
                make(paint, "DoubleYellow_EW", Vector3.new(940, 0.035, 0.18),
                    Vector3.new(center, -0.565, axis + lane),
                    yellow, Enum.Material.SmoothPlastic, false)
                paintCount += 2
            end
        end
    end

    local crossings = Instance.new("Folder")
    crossings.Name = "Crosswalks"
    crossings.Parent = root
    local lampRoot = Instance.new("Folder")
    lampRoot.Name = "Streetlights"
    lampRoot.Parent = root
    local names = Instance.new("Folder")
    names.Name = "DistrictSigns"
    names.Parent = root
    for _, district in Districts do
        local junctionX = math.round(district.x / spacing) * spacing
        local junctionZ = math.round(district.z / spacing) * spacing
        -- Six soft painted zebra lines at the approaches to each center.
        -- Appear only in populated districts, not at all 1225 junctions.
        for n = -3, 3 do
            local shift = n * 2.7
            for _, arm in {-1, 1} do
                make(crossings, "ZebraCrossing", Vector3.new(1.5, 0.04, 7.6),
                    Vector3.new(junctionX + shift, -0.54,
                        junctionZ + arm * (width / 2 + 4)),
                    Color3.fromRGB(217, 221, 214),
                    Enum.Material.SmoothPlastic, false)
                make(crossings, "ZebraCrossing", Vector3.new(7.6, 0.04, 1.5),
                    Vector3.new(junctionX + arm * (width / 2 + 4), -0.54,
                        junctionZ + shift),
                    Color3.fromRGB(217, 221, 214),
                    Enum.Material.SmoothPlastic, false)
            end
        end
        for n = 0, 3 do
            local offset = (n - 1.5) * spacing
            local lampX = junctionX + offset
            local lampZ = junctionZ + width / 2 + 6.0
            local pole = make(lampRoot, "StreetlampPole", Vector3.new(0.48, 14, 0.48),
                Vector3.new(lampX, 6, lampZ),
                Color3.fromRGB(93, 100, 104), Enum.Material.Metal, true)
            pole.CanQuery = true
            local lamp = make(lampRoot, "StreetlampHead", Vector3.new(2.3, 0.35, 1.3),
                Vector3.new(lampX - 1.0, 13.1, lampZ),
                Color3.fromRGB(242, 224, 177), Enum.Material.Neon, false)
            local light = Instance.new("PointLight")
            light.Brightness = 0.75
            light.Range = 25
            light.Shadows = false
            light.Parent = lamp
        end
        local board = make(names, "NeighborhoodSign", Vector3.new(12, 3.2, 0.35),
            Vector3.new(junctionX + 18, 7, junctionZ + 20),
            Color3.fromRGB(40, 92, 112), Enum.Material.Metal, false)
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        gui.PixelsPerStud = 26
        gui.LightInfluence = 0
        gui.Parent = board
        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromScale(1, 1)
        text.BackgroundTransparency = 1
        text.Text = string.upper(district.id)
        text.TextColor3 = Color3.fromRGB(239, 239, 226)
        text.TextScaled = true
        text.Font = Enum.Font.GothamBold
        text.Parent = gui
    end
    print("[StreetCity] Detailed streets: " .. sidewalkCount
        .. " sidewalk sections, " .. paintCount .. " lane stripes, 7 crossings hubs")
end

return Streets
