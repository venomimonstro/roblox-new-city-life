--!strict
-- Bounded procedural infill. Collision: ONE simple anchored shell per building.
-- Every façade, sign and roof item is non-colliding. Plot occupancy is tested
-- against already-created houses, jobs, shops and district building volumes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Infill = {}

local STYLES = {
    downtown = {"Office", "Apartment", "Retail", "Office", "Parking"},
    luxury = {"Condo", "Gallery", "Townhouse", "Condo"},
    oldtown = {"BrickHome", "Retail", "BrickHome", "Abandoned"},
    port = {"Warehouse", "Workshop", "Abandoned", "Warehouse"},
    village = {"Townhouse", "BrickHome", "Retail", "Townhouse"},
    mountains = {"Lodge", "Townhouse", "Workshop"},
    coast = {"Hotel", "Condo", "Retail", "Hotel"},
}

local PALETTES = {
    Office = Color3.fromRGB(103, 120, 138),
    Apartment = Color3.fromRGB(167, 157, 151),
    Retail = Color3.fromRGB(182, 160, 133),
    Parking = Color3.fromRGB(116, 123, 128),
    Condo = Color3.fromRGB(201, 194, 179),
    Gallery = Color3.fromRGB(221, 206, 186),
    Townhouse = Color3.fromRGB(175, 158, 145),
    BrickHome = Color3.fromRGB(151, 103, 90),
    Abandoned = Color3.fromRGB(100, 103, 100),
    Warehouse = Color3.fromRGB(123, 137, 137),
    Workshop = Color3.fromRGB(153, 140, 130),
    Lodge = Color3.fromRGB(136, 118, 99),
    Hotel = Color3.fromRGB(192, 197, 188),
}

local function shape(parent: Instance, name: string, size: Vector3,
    cframe: CFrame, color: Color3, material: Enum.Material, collision: boolean): Part
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cframe
    p.Material, p.Color = material, color
    p.Anchored = true
    p.CanCollide = collision
    p.CanQuery = collision
    p.CanTouch = false
    p.CastShadow = collision
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function shell(parent: Instance, n: number, style: string,
    center: Vector3, size: Vector3, color: Color3)
    local building = Instance.new("Model")
    building.Name = "Infill_" .. tostring(n) .. "_" .. style
    building:SetAttribute("CityInfill", true)
    building:SetAttribute("BuildingStyle", style)
    -- Static building models can stream out and use lightweight SLIM LODs.
    building.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM
    -- Assemble the full model off-Workspace before replicating it once.
    local material = if style == "BrickHome" then Enum.Material.Brick
        elseif style == "Warehouse" or style == "Workshop" then Enum.Material.Metal
        elseif style == "Abandoned" then Enum.Material.Concrete
        else Enum.Material.Concrete
    local core = shape(building, "CollisionShell", size, CFrame.new(center),
        color, material, true)
    building.PrimaryPart = core
    local roofY = center.Y + size.Y / 2
    shape(building, "RoofLip", Vector3.new(size.X + 0.8, 0.6, size.Z + 0.8),
        CFrame.new(center.X, roofY + 0.3, center.Z),
        color:Lerp(Color3.fromRGB(42, 46, 51), 0.35),
        Enum.Material.Concrete, false)

    local isVacant = style == "Abandoned"
    local isGlass = style == "Office" or style == "Hotel" or style == "Condo"
    local window = if isVacant then Color3.fromRGB(43, 48, 48)
        elseif isGlass then Color3.fromRGB(66, 112, 139)
        else Color3.fromRGB(107, 127, 135)
    local faceZ = center.Z - size.Z / 2 - 0.09
    local faceX = center.X + size.X / 2 + 0.09
    -- Two continuous inset window strips, not hundreds of independent panes.
    local floors = math.clamp(math.floor(size.Y / 9), 1, 10)
    for floor = 1, math.min(floors, 6) do
        local y = center.Y - size.Y / 2 + (floor - 0.5) * (size.Y / floors)
        local front = shape(building, "FrontGlazing", Vector3.new(size.X * 0.68, 2.1, 0.13),
            CFrame.new(center.X, y, faceZ), window, Enum.Material.Glass, false)
        front.Transparency = if isVacant then 0 else 0.18
        shape(building, "SideGlazing", Vector3.new(0.13, 2, size.Z * 0.58),
            CFrame.new(faceX, y, center.Z), window, Enum.Material.Glass, false)
    end
    if style == "Retail" or style == "Workshop" or style == "Abandoned" then
        local awning = shape(building, "StreetAwning",
            Vector3.new(size.X * 0.7, 0.25, 1.8),
            CFrame.new(center.X, center.Y - size.Y / 2 + 6.3, faceZ - 0.6),
            if isVacant then Color3.fromRGB(91, 80, 70)
                else Color3.fromRGB(131, 69, 64), Enum.Material.Fabric, false)
        awning.Transparency = if isVacant then 0.35 else 0
    end
    if size.Y > 35 and n % 3 == 0 then
        shape(building, "RooftopHVAC", Vector3.new(5, 2.5, 6),
            CFrame.new(center.X - 5, roofY + 1.6, center.Z + 4),
            Color3.fromRGB(115, 121, 120), Enum.Material.Metal, false)
    end
    building.Parent = parent
    return building
end

-- Reserve a building envelope, including pedestrian space, rather than
-- relying on probabilistic spacing and accidentally blocking a job terminal.
local function available(x: number, z: number, width: number): boolean
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        workspace.Terrain,
        workspace:FindFirstChild("ActiveVehicles") or workspace.Terrain,
    }
    params.MaxParts = 0
    -- Scan only the playable height; ground/roads are below this volume.
    local hits = workspace:GetPartBoundsInBox(
        CFrame.new(x, 14.0, z), Vector3.new(width + 13, 26, width + 13), params)
    for _, hit in hits do
        if hit.CanCollide and hit.Name ~= "Ground"
            and hit.Name ~= "GarageFloor" and hit.Name ~= "HouseFloor"
            and hit.Position.Y + hit.Size.Y / 2 > 0.9 then
            return false
        end
        -- Interactions cannot be buried inside building collision shells.
        if hit:FindFirstChildOfClass("ProximityPrompt") ~= nil
            and hit.Position.Y + hit.Size.Y / 2 > 0.5 then return false end
    end
    return true
end

function Infill.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(not world:FindFirstChild("CityInfill"), "City infill initialized twice")
    local root = Instance.new("Folder")
    root.Name = "CityInfill"
    root.Parent = world
    local total = 0
    for index, district in Districts do
        local zone = Instance.new("Folder")
        zone.Name = district.id
        zone.Parent = root
        local styles = STYLES[district.id]
        local rand = Random.new(74391 + index * 101)
        local baseX = math.floor(district.x / 100) * 100
        local baseZ = math.floor(district.z / 100) * 100
        local placed = 0
        -- One continuous walkable city, but density changes by neighborhood.
        local target = if district.id == "downtown" then 22
            elseif district.id == "village" then 12 else 16
        local positions = {}
        for gridX = -5, 5 do
            for gridZ = -5, 5 do
                local radius = math.max(math.abs(gridX), math.abs(gridZ))
                if radius >= 2 and radius <= 5 then
                    table.insert(positions, {x = baseX + gridX * 100 + 50,
                        z = baseZ + gridZ * 100 + 50})
                end
            end
        end
        -- Deterministic Fisher-Yates to avoid lines of identical cubes.
        for i = #positions, 2, -1 do
            local j = rand:NextInteger(1, i)
            positions[i], positions[j] = positions[j], positions[i]
        end
        for _, cell in positions do
            if placed >= target then break end
            if math.abs(cell.x) > 1680 or math.abs(cell.z) > 1680 then continue end
            local style = styles[rand:NextInteger(1, #styles)]
            local sizeX = rand:NextInteger(23, 33)
            local height = if style == "Office" or style == "Hotel" then rand:NextInteger(40, 85)
                elseif style == "Warehouse" or style == "Parking" then rand:NextInteger(13, 22)
                elseif style == "Condo" then rand:NextInteger(30, 56)
                else rand:NextInteger(15, 37)
            local zWidth = rand:NextInteger(23, 32)
            if not available(cell.x, cell.z, math.max(sizeX, zWidth)) then continue end
            placed += 1
            total += 1
            shell(zone, total, style,
                Vector3.new(cell.x, height / 2 - 1, cell.z),
                Vector3.new(sizeX, height, zWidth),
                PALETTES[style])
        end
        zone:SetAttribute("GeneratedBuildings", placed)
    end
    root:SetAttribute("GeneratedBuildings", total)
    print("[StreetCity] Infill city generated: " .. total
        .. " low-part-count offices, apartments, retail, warehouses and vacant lots")
end

return Infill
