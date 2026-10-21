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
    requireChild(world, "PlayerSpawn", "SpawnLocation")
    requireChild(world, "DistrictBlockouts", "Folder")
    requireChild(world, "PersonalGarageTerminal", "BasePart")
    local locator = requireChild(world, "FindMyCarTerminal", "BasePart")
    requireChild(locator, "ProximityPrompt", "ProximityPrompt")
    requireChild(world, "TimeTrialStart", "BasePart")
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
    requireChild(workspace, "ActiveVehicles", "Folder")
    local remotes = requireChild(ReplicatedStorage, "StreetCityRemotes", "Folder")
    requireChild(remotes, "VehicleInput", "RemoteEvent")
    requireChild(remotes, "ToggleHeadlights", "RemoteEvent")
    requireChild(remotes, "GarageNotice", "RemoteEvent")
    requireChild(ReplicatedStorage, "StreetCityProfileState", "RemoteEvent")
    print("[StreetCity Gate] PASS: critical world, player flow, dealer, race and remotes")
end

return table.freeze(Contract)
