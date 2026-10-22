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
local function buildingFacade(root: Instance, building: BasePart, districtId: string, num: number)
    local tint=palettes[districtId] or palettes.downtown
    local size=building.Size
    local floors=math.clamp(math.floor((size.Y-2)/9),1,10)
    local color=tint[2]
    local mat=Enum.Material.Glass
    for floor=1,floors do
        local y=building.Position.Y-size.Y/2+5+9*(floor-1)
        for column=-1,1 do
            local x=building.Position.X+column*7.8
            for _,sign in {-1,1} do
                detail(root,"Window",Vector3.new(3.7,4,0.12),
                    CFrame.new(x,y,building.Position.Z+sign*(size.Z/2+0.08)),
                    color,mat)
            end
        end
    end
    local door=detail(root,"Entrance",Vector3.new(5,6,0.15),
        CFrame.new(building.Position.X,
            building.Position.Y-size.Y/2+3.2,
            building.Position.Z+size.Z/2+0.1),
        Color3.fromRGB(66,79,88),Enum.Material.Glass)
    local awning=detail(root,"ShopAwning",Vector3.new(10,0.3,3),
        CFrame.new(door.Position+Vector3.new(0,3.5,1.2)),
        tint[1],Enum.Material.Metal)
    if num%2==0 then
        local board=detail(root,"StorefrontSign",Vector3.new(11,2.1,0.2),
            CFrame.new(door.Position+Vector3.new(0,5.7,0)),
            tint[1],Enum.Material.Metal)
        local gui=Instance.new("SurfaceGui")
        gui.Face=Enum.NormalId.Front
        gui.CanvasSize=Vector2.new(440,84)
        gui.LightInfluence=0.15
        gui.Parent=board
        local txt=Instance.new("TextLabel")
        txt.Size=UDim2.fromScale(1,1)
        txt.BackgroundTransparency=1
        txt.Text=signs[(num-1)%#signs+1]
        txt.Font=Enum.Font.GothamBold
        txt.TextScaled=true
        txt.TextColor3=Color3.fromRGB(238,236,227)
        txt.Parent=gui
    end
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
                buildingFacade(sector,building,district.id,n)
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
    -- Road markings ride just above road render surface. Collision/query off.
    local roads=world:WaitForChild("Roads")
    local laneMarks=Instance.new("Folder")
    laneMarks.Name="RoadMarkings"
    laneMarks.Parent=cosmetic
    local stripe=Color3.fromRGB(207,191,133)
    local marked=0
    for _,road in roads:GetChildren() do
        if road:IsA("BasePart") and road.Name:match("NorthSouth")
            and math.abs(road.Position.X) <= 600 then
            detail(laneMarks,"LaneStripe",Vector3.new(0.4,0.04,road.Size.Z-8),
                CFrame.new(road.Position.X,-0.555,road.Position.Z),
                stripe,Enum.Material.SmoothPlastic)
            marked+=1
        elseif road:IsA("BasePart") and road.Name:match("EastWest")
            and math.abs(road.Position.Z) <= 600 then
            detail(laneMarks,"LaneStripe",Vector3.new(road.Size.X-8,0.04,0.4),
                CFrame.new(road.Position.X,-0.55,road.Position.Z),
                stripe,Enum.Material.SmoothPlastic)
            marked+=1
        end
    end
    print("[StreetCity] District detail pass: "..count.." facades, streetlamps, "..marked.." lane markings")
end
return Decor
