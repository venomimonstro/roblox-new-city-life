--!strict
-- Deterministic cosmetic district facades. Noncolliding details ensure that
-- decorative windows and props cannot snag players, NPCs, or car suspension.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Decor = {}
local palettes = {
    downtown = {Color3.fromRGB(79,103,132),Color3.fromRGB(178,196,208)},
    luxury = {Color3.fromRGB(173,164,142),Color3.fromRGB(218,218,204)},
    oldtown = {Color3.fromRGB(163,119,94),Color3.fromRGB(214,188,157)},
    port = {Color3.fromRGB(82,115,119),Color3.fromRGB(168,188,175)},
    village = {Color3.fromRGB(121,147,106),Color3.fromRGB(206,194,139)},
    mountains = {Color3.fromRGB(100,119,102),Color3.fromRGB(178,190,166)},
    coast = {Color3.fromRGB(137,164,172),Color3.fromRGB(229,213,168)},
}
local signs = {"MARKET", "CAFE", "REPAIRS", "HOTEL", "OFFICE", "STUDIO", "GALLERY"}
local function detail(parent: Instance, name: string, size: Vector3,
    frame: CFrame, color: Color3, material: Enum.Material): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size,part.CFrame = size,frame
    part.Anchored=true
    part.CanCollide=false
    part.CanQuery=false
    part.CanTouch=false
    part.Material=material
    part.Color=color
    part.CastShadow=false
    part.Parent=parent
    return part
end
local function streetlight(parent: Instance, position: Vector3)
    detail(parent,"LanternPost",Vector3.new(0.3,12,0.3),
        CFrame.new(position+Vector3.new(0,6,0)),
        Color3.fromRGB(56,65,70),Enum.Material.Metal)
    local glass=detail(parent,"StreetLamp",Vector3.new(2.5,0.6,2.5),
        CFrame.new(position+Vector3.new(0,12,0)),
        Color3.fromRGB(253,214,154),Enum.Material.Neon)
    local light=Instance.new("PointLight")
    light.Brightness=0.8
    light.Range=28
    light.Shadows=false
    light.Parent=glass
end
-- CityArchitecture is the ONLY facade/window generator. This service adds
-- storefront identity and lamps without double-layered windows and z-fighting.
local function storefrontIdentity(root: Instance, building: BasePart, districtId: string, num: number)
    if num % 2 ~= 0 then return end
    local tint = palettes[districtId] or palettes.downtown
    local front = building.Position.Z + building.Size.Z / 2 + 0.23
    local ground = building.Position.Y - building.Size.Y / 2
    local board = detail(root, "StorefrontSign", Vector3.new(11, 2.1, 0.2),
        CFrame.new(building.Position.X, ground + 6.2, front),
        tint[1], Enum.Material.Metal)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.CanvasSize = Vector2.new(440, 84)
    gui.LightInfluence = 0.15
    gui.Parent = board
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.Text = signs[(num - 1) % #signs + 1]
    txt.Font = Enum.Font.GothamBold
    txt.TextScaled = true
    txt.TextColor3 = Color3.fromRGB(238, 236, 227)
    txt.Parent = gui
end
function Decor.Start()
    local world=workspace:WaitForChild("StreetCityPrototypeWorld")
    local districts=world:WaitForChild("DistrictBlockouts")
    local cosmetic=Instance.new("Folder")
    cosmetic.Name="DistrictDetails"
    cosmetic.Parent=world
    local count=0
    for _,district in Districts do
        local area=districts:WaitForChild(district.id)
        local sector=Instance.new("Folder")
        sector.Name=district.id
        sector.Parent=cosmetic
        local n=0
        for _,building in area:GetChildren() do
            if building:IsA("BasePart") and building.Name:match("^Building_") then
                n+=1
                storefrontIdentity(sector,building,district.id,n)
                count+=1
            end
        end
        -- Carefully situated in street blocks, rather than the driving lanes.
        local cx=math.floor(district.x/100)*100
        local cz=math.floor(district.z/100)*100
        for dx=-1,1 do
            for dz=-1,1 do
                streetlight(sector,Vector3.new(cx+dx*100+21,0,cz+dz*100+21))
            end
        end
    end
    print("[StreetCity] District detail pass: "..count.." storefront profiles, streetlamps")
end
return Decor
