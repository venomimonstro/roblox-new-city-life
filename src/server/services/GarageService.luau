--!strict
-- Temporary development garage: cycles approved presets, no currency/persistence.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleBuild = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleBuild"))
local GarageService = {}
local presets = {
    { name = "Street", engineId = "stock_i4", gearboxId = "street_5", tireId = "street" },
    { name = "Sport", engineId = "sport_i4", gearboxId = "sport_6", tireId = "sport" },
    { name = "Used parts", engineId = "stock_i4", gearboxId = "street_5", tireId = "worn" },
}

function GarageService.Start(car)
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
    local stand = Instance.new("Part")
    stand.Name = "TestTuningStand"
    stand.Anchored = true
    stand.Size = Vector3.new(9, 1, 9)
    stand.Position = Vector3.new(20, 0, -32)
    stand.Material = Enum.Material.Neon
    stand.Color = Color3.fromRGB(61, 153, 190)
    stand.Parent = root

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Change test build"
    prompt.ObjectText = "Development garage"
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = stand

    local current = 1
    local busy = false
    prompt.Triggered:Connect(function(player: Player)
        if busy or not player.Character or not player.Character:FindFirstChildOfClass("Humanoid") then return end
        if player:DistanceFromCharacter(stand.Position) > 11 then return end
        if car.Seat.Occupant ~= nil then return end
        if car.Chassis.AssemblyLinearVelocity.Magnitude > 2 then return end
        busy = true
        local nextIndex = current % #presets + 1
        local preset = presets[nextIndex]
        if VehicleBuild.Resolve(preset) then
            car.Model:SetAttribute("EngineId", preset.engineId)
            car.Model:SetAttribute("GearboxId", preset.gearboxId)
            car.Model:SetAttribute("TireId", preset.tireId)
            car.Model:SetAttribute("BuildName", preset.name)
            current = nextIndex
            print("[StreetCity] Test garage applied preset: " .. preset.name)
        end
        busy = false
    end)
end

return GarageService
