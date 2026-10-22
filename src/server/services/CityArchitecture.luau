--!strict
-- Lightweight procedural facades over a single solid collision core.
-- Detailed parts NEVER affect vehicle or player raycasts. Replace this module's
-- decorative facade with authored MeshParts without changing stable collisions.
local Architecture = {}

local palettes: {[string]: {Color3}} = {
    downtown = {Color3.fromRGB(104, 120, 141), Color3.fromRGB(160, 172, 177), Color3.fromRGB(139, 128, 119)},
    luxury = {Color3.fromRGB(210, 203, 188), Color3.fromRGB(174, 183, 179), Color3.fromRGB(192, 175, 154)},
    oldtown = {Color3.fromRGB(177, 135, 109), Color3.fromRGB(187, 168, 138), Color3.fromRGB(163, 152, 140)},
    port = {Color3.fromRGB(134, 142, 149), Color3.fromRGB(174, 164, 143), Color3.fromRGB(130, 158, 159)},
    village = {Color3.fromRGB(192, 173, 143), Color3.fromRGB(164, 190, 174), Color3.fromRGB(192, 162, 155)},
    mountains = {Color3.fromRGB(153, 144, 130), Color3.fromRGB(130, 157, 145), Color3.fromRGB(178, 162, 137)},
    coast = {Color3.fromRGB(218, 204, 173), Color3.fromRGB(196, 218, 215), Color3.fromRGB(207, 189, 174)},
}

local GLASS = Color3.fromRGB(80, 132, 164)
local WARM_GLASS = Color3.fromRGB(205, 177, 119)
local IRON = Color3.fromRGB(55, 68, 79)

local function detail(parent: Instance, name: string, size: Vector3, frame: CFrame,
    color: Color3, material: Enum.Material): Part
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
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function windows(parent: Instance, core: Part, side: number, floor: number,
    columns: number, warm: boolean)
    local y = core.Position.Y - core.Size.Y / 2 + 3.2 + floor * 7.5
    local exterior = core.Position.Z + side * (core.Size.Z / 2 + 0.09)
    for column = 1, columns do
        local x = core.Position.X + (column - (columns + 1) / 2) * 8
        local glass = detail(parent, "GlazedWindow", Vector3.new(4.5, 4.1, 0.14),
            CFrame.new(x, y, exterior),
            if warm then WARM_GLASS else GLASS, Enum.Material.Glass)
        glass.Transparency = if warm then 0.11 else 0.2
        detail(parent, "WindowMullion", Vector3.new(0.12, 4.15, 0.23),
            CFrame.new(x, y, exterior + side * 0.03), IRON, Enum.Material.Metal)
        detail(parent, "WindowSill", Vector3.new(5, 0.16, 0.55),
            CFrame.new(x, y - 2.12, exterior), Color3.fromRGB(180, 181, 175),
            Enum.Material.Concrete)
    end
end

function Architecture.DecorateBuilding(parent: Instance, core: Part, districtId: string,
    number: number)
    local colors = palettes[districtId] or palettes.downtown
    local style = number % 3
    core.Color = colors[number % #colors + 1]
    core.Material = if districtId == "oldtown" or districtId == "village"
        then Enum.Material.Brick else Enum.Material.Concrete
    core.TopSurface = Enum.SurfaceType.Smooth
    core.BottomSurface = Enum.SurfaceType.Smooth
    local facade = Instance.new("Model")
    facade.Name = "Facade_" .. core.Name
    facade:SetAttribute("District", districtId)
    facade:SetAttribute("DecorativeOnly", true)
    -- Keep distant windows/roof details as a small SLIM representation, not
    -- hundreds of full-resolution façade parts on low-memory clients.
    facade.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM
    facade.Parent = parent
    local floorCount = math.min(10, math.floor((core.Size.Y - 3) / 7.5))
    -- The core is a solid cheap collision volume; the visual facade is separate.
    for floor = 1, floorCount do
        windows(facade, core, -1, floor - 1, 3, (number + floor) % 4 == 0)
        windows(facade, core, 1, floor - 1, 3, (number + floor + 1) % 4 == 0)
        if style == 0 then
            local y = core.Position.Y - core.Size.Y / 2 + floor * 7.5
            detail(facade, "FloorBand", Vector3.new(core.Size.X + 0.6, 0.26, core.Size.Z + 0.6),
                CFrame.new(core.Position.X, y, core.Position.Z),
                Color3.fromRGB(177, 183, 185), Enum.Material.Concrete)
        end
    end
    local roofY = core.Position.Y + core.Size.Y / 2
    detail(facade, "RoofCap", Vector3.new(core.Size.X + 1.5, 0.65, core.Size.Z + 1.5),
        CFrame.new(core.Position.X, roofY + 0.3, core.Position.Z),
        if style == 1 then Color3.fromRGB(96, 105, 112)
            else Color3.fromRGB(73, 82, 88), Enum.Material.Concrete)
    if core.Size.Y >= 35 then
        detail(facade, "RooftopEquipment", Vector3.new(6, 2.2, 8),
            CFrame.new(core.Position.X + 7, roofY + 1.75, core.Position.Z + 4),
            Color3.fromRGB(112, 122, 130), Enum.Material.Metal)
    end
    -- Front porch and recessed-looking doors are visual; they do not close roads.
    local front = core.Position.Z - core.Size.Z / 2 - 0.18
    local lobby = detail(facade, "LobbyGlass", Vector3.new(7.2, 6.2, 0.3),
        CFrame.new(core.Position.X, core.Position.Y - core.Size.Y / 2 + 3, front),
        Color3.fromRGB(58, 83, 102), Enum.Material.Glass)
    lobby.Transparency = 0.13
    detail(facade, "EntranceCanopy", Vector3.new(10, 0.5, 3.0),
        CFrame.new(core.Position.X, core.Position.Y - core.Size.Y / 2 + 6.3, front - 1.1),
        Color3.fromRGB(76, 83, 92), Enum.Material.Metal)
    detail(facade, "EntryLight", Vector3.new(1.8, 0.2, 0.8),
        CFrame.new(core.Position.X, core.Position.Y - core.Size.Y / 2 + 6, front - 2.0),
        Color3.fromRGB(243, 222, 161), Enum.Material.Neon)
    return facade
end

function Architecture.DecorateHome(estate: Model, plot: any, slot: number)
    local house = estate:FindFirstChild("House")
    if not house or not house:IsA("BasePart") then return end
    local exterior = Instance.new("Folder")
    exterior.Name = "ResidentialFacade"
    exterior.Parent = estate
    local towardsRoad = if slot < 24 then 1 else -1
    local yTop = house.Position.Y + house.Size.Y / 2
    local x, z = house.Position.X, house.Position.Z
    local facing = z + towardsRoad * (house.Size.Z / 2 + 0.08)
    house.Material = if slot % 3 == 0 then Enum.Material.Brick else Enum.Material.Concrete
    -- Two separate sloping roof planes: pitched American-style homes.
    local roofColor = if slot % 4 == 0 then Color3.fromRGB(91, 67, 65)
        elseif slot % 4 == 1 then Color3.fromRGB(55, 69, 85)
        elseif slot % 4 == 2 then Color3.fromRGB(82, 86, 76)
        else Color3.fromRGB(116, 83, 58)
    for _, side in {-1, 1} do
        detail(exterior, "PitchedRoof", Vector3.new(7.5, 0.7, 18.5),
            CFrame.new(x + side * 3, yTop + 1.0, z)
                * CFrame.Angles(0, 0, math.rad(side * 18)),
            roofColor, Enum.Material.Slate)
    end
    local door = detail(exterior, "FrontDoor", Vector3.new(2.7, 5.5, 0.16),
        CFrame.new(x, house.Position.Y - house.Size.Y / 2 + 2.8, facing),
        Color3.fromRGB(72, 84, 94), Enum.Material.Wood)
    -- Unlike decorative windows, the entry really closes a walkable doorway.
    door.CanCollide = true
    door.CanQuery = true
    detail(exterior, "DoorHandle", Vector3.new(0.16, 0.22, 0.25),
        CFrame.new(x + 0.8, house.Position.Y - house.Size.Y / 2 + 2.8,
            facing + towardsRoad * 0.16), Color3.fromRGB(216, 188, 111),
        Enum.Material.Metal)
    for _, side in {-1, 1} do
        for _, floor in {0, 1} do
            local paneY = house.Position.Y - house.Size.Y / 2 + 3.2 + floor * 5.7
            local wx = x + side * 4.1
            local win = detail(exterior, "HomeWindow", Vector3.new(2.7, 2.6, 0.18),
                CFrame.new(wx, paneY, facing), GLASS, Enum.Material.Glass)
            win.Transparency = 0.14
            detail(exterior, "WindowCrossbar", Vector3.new(0.12, 2.7, 0.2),
                CFrame.new(wx, paneY, facing + towardsRoad * 0.05),
                Color3.fromRGB(233, 230, 216), Enum.Material.Wood)
            detail(exterior, "WindowSill", Vector3.new(3.1, 0.16, 0.45),
                CFrame.new(wx, paneY - 1.4, facing),
                Color3.fromRGB(228, 219, 200), Enum.Material.Concrete)
        end
    end
    -- Actual roof support: players must not fall into an attic through
    -- collision-free pitched roof decoration.
    local ceiling = Instance.new("Part")
    ceiling.Name = "HouseCeiling"
    ceiling.Size = Vector3.new(12.7, 0.35, 15.7)
    ceiling.Position = Vector3.new(x, yTop + 0.05, z)
    ceiling.Color = Color3.fromRGB(201, 195, 181)
    ceiling.Material = Enum.Material.WoodPlanks
    ceiling.Anchored = true
    ceiling.CanCollide = true
    ceiling.CanQuery = true
    ceiling.Parent = estate
    local garage = estate:FindFirstChild("GarageRoof")
    if garage and garage:IsA("BasePart") then
        garage.Material = Enum.Material.Slate
        garage.Color = roofColor
        detail(exterior, "GarageFascia",
            Vector3.new(14.6, 0.8, 0.65),
            CFrame.new(plot.garage.X, 11.85, plot.garage.Z + towardsRoad * 13.25),
            Color3.fromRGB(225, 222, 213), Enum.Material.Concrete)
        -- Open driveway: the roller door is deliberately transparent to physics.
        for _, offset in {-3.9, 3.9} do
            detail(exterior, "GarageEdge", Vector3.new(0.4, 8, 0.35),
                CFrame.new(plot.garage.X + offset, 4,
                    plot.garage.Z + towardsRoad * 13.25),
                Color3.fromRGB(226, 222, 208), Enum.Material.Metal)
        end
    end
    -- Landscaped yards and street furniture are lightweight and noncolliding,
    -- so nobody gets snagged while running to their garage.
    for _, side in {-1, 1} do
        local trunk = detail(exterior, "GardenTreeTrunk",
            Vector3.new(0.8, 5.5, 0.8),
            CFrame.new(x + side * 10.0, 2.0, z + side * 3),
            Color3.fromRGB(104, 76, 51), Enum.Material.Wood)
        local crown = detail(exterior, "GardenTreeCrown",
            Vector3.new(5.8, 5.8, 5.8),
            trunk.CFrame * CFrame.new(0, 3.4, 0),
            if slot % 2 == 0 then Color3.fromRGB(86, 137, 86)
            else Color3.fromRGB(105, 143, 80), Enum.Material.Grass)
        crown.Shape = Enum.PartType.Ball
        for i = 1, 3 do
            local hedge = detail(exterior, "YardHedge",
                Vector3.new(2.0, 1.15, 1.35),
                CFrame.new(x + side * (8.2 + i * 1.9), -0.3,
                    z + towardsRoad * (2 + i * 1.65)),
                Color3.fromRGB(62, 112, 65), Enum.Material.Grass)
            hedge.Shape = Enum.PartType.Ball
        end
    end
    detail(exterior, "MailboxPost", Vector3.new(0.34, 2.4, 0.34),
        CFrame.new(plot.garage.X - 8.4, 0.25,
            plot.garage.Z + towardsRoad * 15.8),
        Color3.fromRGB(109, 100, 87), Enum.Material.Wood)
    detail(exterior, "Mailbox",
        Vector3.new(1.55, 0.8, 1.2),
        CFrame.new(plot.garage.X - 8.4, 1.5,
            plot.garage.Z + towardsRoad * 15.8),
        Color3.fromRGB(74, 94, 115), Enum.Material.Metal)
    local sign = estate:FindFirstChild("GarageTerminal")
    if sign and sign:IsA("BasePart") then
        sign.Size = Vector3.new(1.25, 2.2, 1.25)
        sign.Material = Enum.Material.Metal
        detail(exterior, "NumberPlate", Vector3.new(1.6, 0.9, 0.2),
            CFrame.new(sign.Position.X, sign.Position.Y + 1.1, sign.Position.Z),
            Color3.fromRGB(235, 226, 199), Enum.Material.SmoothPlastic)
    end
    return door
end

return Architecture
