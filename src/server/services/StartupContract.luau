--!strict
-- Production-safe startup contract. Does not use DataStore or create instances.
-- A partial world is never advertised as a ready game server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Course = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceCourse"))
local Contract = {}

local function requireChild(parent: Instance?, name: string, expectedClass: string): Instance
    assert(parent ~= nil, "[StreetCity Gate] Missing parent of " .. name)
    local value = parent:FindFirstChild(name)
    assert(value ~= nil, "[StreetCity Gate] Missing " .. name)
    assert(value:IsA(expectedClass),
        "[StreetCity Gate] Wrong class for " .. name .. ": " .. value.ClassName)
    return value
end

function Contract.Validate()
    local world = requireChild(workspace, "StreetCityPrototypeWorld", "Folder")
    requireChild(world, "Ground", "BasePart")
    requireChild(world, "Roads", "Folder")
    local boundaries = requireChild(world, "WorldLimits", "Folder")
    assert(#boundaries:GetChildren() == 4,
        "[StreetCity Gate] Map border collision missing; players could fall into void")
    for _, edge in boundaries:GetChildren() do
        assert(edge:IsA("BasePart") and edge.CanCollide and not edge.CanQuery,
            "[StreetCity Gate] World perimeter must block falling but not spoil raycasts")
    end
    local streets = requireChild(world, "StreetEnvironment", "Folder")
    local walks = requireChild(streets, "Sidewalks", "Folder")
    local lines = requireChild(streets, "LanePaint", "Folder")
    local crossings = requireChild(streets, "Crosswalks", "Folder")
    local lighting = requireChild(streets, "Streetlights", "Folder")
    assert(#walks:GetChildren() >= 500 and #lines:GetChildren() >= 500
        and #crossings:GetChildren() >= 90 and #lighting:GetChildren() >= 20,
        "[StreetCity Gate] Streets missing sidewalks, markings, crossings or lights")
    requireChild(world, "PlayerSpawn", "SpawnLocation")
    requireChild(world, "DistrictBlockouts", "Folder")
    local residential = requireChild(world, "ResidentialHomes", "Folder")
    assert(#residential:GetChildren() == 48,
        "[StreetCity Gate] Exactly 48 physical home and garage plots expected")
    for _, home in residential:GetChildren() do
        local terminal = requireChild(home, "GarageTerminal", "BasePart")
        requireChild(terminal, "GaragePrompt", "ProximityPrompt")
        local shell = requireChild(home, "House", "BasePart")
        assert(not shell.CanCollide, "[StreetCity Gate] Home reverted to solid cube")
        requireChild(home, "HouseFloor", "BasePart")
        local ceiling = requireChild(home, "HouseCeiling", "BasePart")
        assert(ceiling.CanCollide, "[StreetCity Gate] Roof lets avatars fall into house")
        local door = home:FindFirstChild("FrontDoor", true)
        assert(door and door:IsA("BasePart") and door.CanCollide
            and door:FindFirstChild("FrontDoorPrompt"),
            "[StreetCity Gate] A house has no physical interactive doorway")
    end
    requireChild(world, "PersonalGarageTerminal", "BasePart")
    local locator = requireChild(world, "FindMyCarTerminal", "BasePart")
    requireChild(locator, "ProximityPrompt", "ProximityPrompt")
    local propertyShops = requireChild(world, "DistrictProperties", "Folder")
    local bankBranches = requireChild(world, "BankBranches", "Folder")
    local crewOffices = requireChild(world, "CityCrews", "Folder")
    local influence = requireChild(world, "TerritoryControl", "Folder")
    assert(#influence:GetChildren() == 7,
        "[StreetCity Gate] Seven competing territory points required")
    for _, site in influence:GetChildren() do
        local prompt = requireChild(site, "ProximityPrompt", "ProximityPrompt")
        assert(prompt.Enabled, "[StreetCity Gate] Inactive territory capture point")
    end
    local nature = requireChild(world, "CityNature", "Folder")
    requireChild(world, "CityRealEstate", "Folder")
    -- The application/approval-based CrewService is authoritative.
    -- A second FactionRegistry would let teams diverge, so it is not required.
    assert(#propertyShops:GetChildren() >= 49,
        "[StreetCity Gate] Personal property markets incomplete")
    assert(#bankBranches:GetChildren() >= 9,
        "[StreetCity Gate] Regional banking branch network incomplete")
    assert(#crewOffices:GetChildren() >= 10,
        "[StreetCity Gate] Player crew recruitment offices incomplete")
    assert(#nature:GetChildren() >= 7,
        "[StreetCity Gate] Wildlife and nature districts incomplete")
    requireChild(ReplicatedStorage, "StreetCityDistrictState", "RemoteEvent")
    requireChild(world, "TimeTrialStart", "BasePart")
    local jobs = requireChild(world, "CityJobs", "Folder")
    local citizens = requireChild(world, "CityPedestrians", "Folder")
    assert(#citizens:GetChildren() >= 20,
        "[StreetCity Gate] City pedestrian population missing")
    for _, jobId in {"taxi", "firefighter", "police", "cleaner", "office"} do
        requireChild(jobs, "JobStart_" .. jobId, "BasePart")
        requireChild(jobs, "JobFinish_" .. jobId, "BasePart")
    end
    requireChild(jobs, "Fish_Cast", "BasePart")
    requireChild(jobs, "Fish_Catch", "BasePart")
    requireChild(jobs, "Fish_Sell", "BasePart")
    local careers = requireChild(world, "LegalCareers", "Folder")
    local jobCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LegalCareerCatalog"))
    for _, job in jobCatalog do
        local stand = requireChild(careers, "CareerStart_" .. job.id, "BasePart")
        requireChild(stand, "CareerPrompt", "ProximityPrompt")
        assert(not stand.CanCollide and not stand.CanQuery,
            "[StreetCity Gate] Career stand obstructs road")
    end
    local clinic = requireChild(world, "StreetCityHospital", "Folder")
    requireChild(clinic, "RepayMedicalDebt", "BasePart")
    local bountyBoard = requireChild(world, "PoliceBountyBoard", "BasePart")
    requireChild(bountyBoard, "ProximityPrompt", "ProximityPrompt")
    for index = 1, #Course.Points do
        local marker = requireChild(world, "CircuitCheckpoint_" .. tostring(index), "BasePart")
        assert(not marker.CanCollide and not marker.CanQuery,
            "[StreetCity Gate] Checkpoint cannot obstruct or spoof ground raycast")
    end
    local stands = 0
    for _, instance in world:GetChildren() do
        if string.sub(instance.Name, 1, 5) == "Shop_" then
            assert(instance:IsA("BasePart") and not instance.CanCollide
                and not instance.CanQuery, "[StreetCity Gate] Obstructing shop stand")
            assert(instance:FindFirstChildOfClass("ProximityPrompt"),
                "[StreetCity Gate] Shop without interaction prompt")
            stands += 1
        end
    end
    assert(stands >= 11, "[StreetCity Gate] Incomplete dealership or part shop")
    local vehicles = requireChild(workspace, "ActiveVehicles", "Folder")
    local npcCars = 0
    for _, car in vehicles:GetChildren() do
        if car:GetAttribute("TrafficNPC") == true then npcCars += 1 end
    end
    assert(npcCars >= 6, "[StreetCity Gate] Ambient traffic agents failed to spawn")
    local remotes = requireChild(ReplicatedStorage, "StreetCityRemotes", "Folder")
    requireChild(remotes, "VehicleInput", "RemoteEvent")
    requireChild(remotes, "ToggleHeadlights", "RemoteEvent")
    requireChild(remotes, "GarageNotice", "RemoteEvent")
    requireChild(ReplicatedStorage, "StreetCityWantedState", "RemoteEvent")
    requireChild(ReplicatedStorage, "StreetCitySprintRequest", "RemoteEvent")
    requireChild(ReplicatedStorage, "StreetCityProfileState", "RemoteEvent")
    requireChild(ReplicatedStorage, "StreetCityCareerStatus", "RemoteEvent")
    requireChild(ReplicatedStorage, "StreetCityWantedPosters", "RemoteEvent")
    for _, home in residential:GetChildren() do
        requireChild(home, "HomeCash_Deposit", "BasePart")
        requireChild(home, "HomeCash_Withdraw", "BasePart")
    end
    print("[StreetCity Gate] PASS: critical world, player flow, dealer, race and remotes")
end

return table.freeze(Contract)
