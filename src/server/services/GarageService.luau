--!strict
-- Server-authorized personal test garage. Persistent only after confirmed DataStore write.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleBuild = require(ReplicatedStorage.Shared:WaitForChild("VehicleBuild"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local GarageService = {}
local presets = {
    {name="Street", engineId="stock_i4", gearboxId="street_5", tireId="street"},
    {name="Sport", engineId="sport_i4", gearboxId="sport_6", tireId="sport"},
    {name="Used parts", engineId="stock_i4", gearboxId="street_5", tireId="worn"},
}
local devIndex: { [number]: number } = {}

function GarageService.Start(car: any)
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local stand = Instance.new("Part")
    stand.Name = "TestTuningStand"
    stand.Anchored = true
    stand.Size = Vector3.new(9, 1, 9)
    stand.Position = Vector3.new(20, 0, -32)
    stand.Material = Enum.Material.Neon
    stand.Color = Color3.fromRGB(61, 153, 190)
    stand.Parent = world
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Change test build"
    prompt.ObjectText = "Development garage"
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = stand
    local busy = false
    prompt.Triggered:Connect(function(player: Player)
        if busy or not player.Character then return end
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        if player:DistanceFromCharacter(stand.Position) > 11 then return end
        if car.Seat.Occupant or car.Chassis.AssemblyLinearVelocity.Magnitude > 2 then return end
        local nextIndex = (devIndex[player.UserId] or 1) % #presets + 1
        local build = presets[nextIndex]
        if not VehicleBuild.Resolve(build) then return end
        busy = true
        local updated = false
        if ProfileService.IsLoaded(player) then
            updated = ProfileService.Mutate(player, function(profile)
                if not profile or not profile.garage or not profile.garage.starter then return false end
                profile.garage.starter = {
                    engineId = build.engineId,
                    gearboxId = build.gearboxId,
                    tireId = build.tireId,
                }
                return true
            end)
        elseif game:GetService("RunService"):IsStudio() and game.GameId == 0 then
            -- Local unpublished Studio testing only; cannot be persisted.
            updated = true
        end
        if updated then
            car.Model:SetAttribute("EngineId", build.engineId)
            car.Model:SetAttribute("GearboxId", build.gearboxId)
            car.Model:SetAttribute("TireId", build.tireId)
            car.Model:SetAttribute("BuildName", build.name)
            devIndex[player.UserId] = nextIndex
        end
        busy = false
    end)
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        devIndex[player.UserId] = nil
    end)
end
return GarageService
