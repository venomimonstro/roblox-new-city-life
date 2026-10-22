--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Map = require(Shared:WaitForChild("TransitMap"))
local Life = require(Shared:WaitForChild("NpcLifeRules"))
local Test = {}
function Test.Run()
    assert(#Map.Metro == 3 and #Map.Bus == 5, "Transit stop count changed")
    local world = workspace:FindFirstChild("StreetCityPrototypeWorld")
    local root = world and world:FindFirstChild("PublicTransit")
    assert(root, "Public transit not initialized")
    local tunnel = root:FindFirstChild("UndergroundLine")
    assert(tunnel and tunnel:FindFirstChild("MetroTrain")
        and tunnel:FindFirstChild("MetroTunnelFloor"), "Metro underground model missing")
    for _, stop in Map.Metro do
        local entrance = root:FindFirstChild("MetroEntrance_" .. stop.id)
        local platform = tunnel:FindFirstChild("Platform_" .. stop.id)
        assert(entrance and platform and platform.Position.Y < -20,
            "Metro station surface/underground continuity missing")
        assert(entrance:FindFirstChildOfClass("ProximityPrompt"),
            "Metro street entrance has no boarding prompt")
        local platformGate = tunnel:FindFirstChild("PlatformAccess_" .. stop.id)
        local exit = tunnel:FindFirstChild("MetroExit_" .. stop.id)
        assert(platformGate and platformGate:FindFirstChildOfClass("ProximityPrompt")
            and exit and exit:FindFirstChildOfClass("ProximityPrompt"),
            "Metro must allow street-platform-ride-street journey")
    end
    for _, stop in Map.Bus do
        local station = root:FindFirstChild("BusStop_" .. stop.id)
        assert(station and station:FindFirstChildOfClass("ProximityPrompt"),
            "Bus stop has no boarding prompt")
        assert(not station.CanCollide and not station.CanQuery,
            "Bus station blocks a city roadway")
    end
    assert(root:FindFirstChild("CityBusNPC"), "City bus visual agent missing")
    local count = 0
    for i = 1, 28 do
        local p = Life.New(i, "downtown")
        assert(p.id == i and type(p.occupation) == "string"
            and type(p.hasCar) == "boolean" and type(p.married) == "boolean")
        local prior = p.minute
        local ev = Life.Advance(p, 1, 50)
        assert(p.minute > prior and type(ev) == "string")
        assert(Life.Advance(p, 1, 50) == ev, "NPC time must not replay twice")
        for tick = 2, 160 do
            Life.Advance(p, tick, if tick % 2 == 0 then 20 else 85)
        end
        assert(p.incidents <= 99 and p.relationships >= 0
            and p.trips >= 0, "NPC life unbounded state")
        count += 1
    end
    local citizens = world:FindFirstChild("CityPedestrians")
    assert(citizens and #citizens:GetChildren() == count, "NPC population mismatch")
    for _, npc in citizens:GetChildren() do
        assert(npc:GetAttribute("Occupation") ~= nil
            and npc:GetAttribute("Mood") ~= nil
            "NPC initial identity missing")
    end
    print("[StreetCity] PASS: metro, bus stops and 28 bounded NPC life simulations")
end
return Test
