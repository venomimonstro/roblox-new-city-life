--!strict
-- Deterministic traffic lights at the busiest streets. Models are cosmetic:
-- the AI gets a separate server-authoritative StopForRed result.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signals = {}
local POSITIONS = {
    Vector3.new(100,0,100), Vector3.new(-100,0,100),
    Vector3.new(100,0,-100), Vector3.new(-100,0,-100),
    Vector3.new(200,0,200), Vector3.new(-200,0,200),
    Vector3.new(200,0,-200), Vector3.new(-200,0,-200),
}
local heads: {any} = {}
local timeBase = os.clock()
local PERIOD = 34
local function greenFor(vertical: boolean): boolean
    local phase = (os.clock() - timeBase) % PERIOD
    return if vertical then phase < 14 else phase >= 17 and phase < 31
end
local function makePart(parent: Instance, name: string, size: Vector3,
    pos: Vector3, color: Color3): Part
    local p=Instance.new("Part")
    p.Name,p.Size,p.Position=name,size,pos
    p.Anchored=true
    p.CanCollide=false
    p.CanQuery=false
    p.CanTouch=false
    p.Color=color
    p.Material=Enum.Material.Metal
    p.Parent=parent
    return p
end
function Signals.ShouldStop(position: Vector3, facing: Vector3): boolean
    local vertical = math.abs(facing.Z) > math.abs(facing.X)
    if greenFor(vertical) then return false end
    local best = 100
    for _, crossing in POSITIONS do
        local offset = crossing - position
        local longitudinal = Vector3.new(offset.X,0,offset.Z):Dot(facing)
        local lateral = if vertical then math.abs(offset.X) else math.abs(offset.Z)
        if longitudinal > 12 and longitudinal < 50
            and lateral < 9 and longitudinal < best then
            best=longitudinal
        end
    end
    return best < 100
end
function Signals.Start()
    local world=workspace:WaitForChild("StreetCityPrototypeWorld")
    local root=Instance.new("Folder")
    root.Name="TrafficSignals"
    root.Parent=world
    for n,crossing in POSITIONS do
        local model=Instance.new("Model")
        model.Name="Signal_"..n
        model.Parent=root
        for index,offset in {
            Vector3.new(17,0,17), Vector3.new(-17,0,-17),
            Vector3.new(17,0,-17), Vector3.new(-17,0,17),
        } do
            local vertical = index <= 2
            local pos = crossing + offset
            makePart(model,"SignalPole",Vector3.new(0.3,12,0.3),
                pos+Vector3.new(0,6,0),Color3.fromRGB(60,66,69))
            local housing=makePart(model,"SignalHousing",
                Vector3.new(1.9,4.7,1.5),pos+Vector3.new(0,12,0),
                Color3.fromRGB(34,40,45))
            local lights={}
            for li=1,3 do
                local lamp=makePart(model,{"Red","Amber","Green"}[li],
                    Vector3.new(1,1,0.2),
                    pos+Vector3.new(0,14-li,0.85),
                    Color3.fromRGB(25,30,35))
                lamp.Material=Enum.Material.Neon
                lights[li]=lamp
            end
            table.insert(heads,{vertical=vertical,lights=lights})
        end
    end
    task.spawn(function()
        while root.Parent do
            for _,item in heads do
                local go=greenFor(item.vertical)
                local phase=(os.clock()-timeBase)%PERIOD
                local caution = if item.vertical then phase>=14 and phase<17
                    else phase>=31 and phase<34
                item.lights[1].Color = if not go and not caution
                    then Color3.fromRGB(240,62,47) else Color3.fromRGB(43,22,18)
                item.lights[2].Color = if caution
                    then Color3.fromRGB(245,184,49) else Color3.fromRGB(41,32,18)
                item.lights[3].Color = if go
                    then Color3.fromRGB(69,219,104) else Color3.fromRGB(17,40,21)
            end
            task.wait(0.6)
        end
    end)
    print("[StreetCity] Eight adaptive intersections use one server traffic phase")
end
return Signals
