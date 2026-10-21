--!strict
local RunService = game:GetService("RunService")

local Services = script.Parent:WaitForChild("services")
local WorldService = require(Services:WaitForChild("WorldService"))
local VehicleService = require(Services:WaitForChild("VehicleService"))
local DistrictService = require(Services:WaitForChild("DistrictService"))
local GarageService = require(Services:WaitForChild("GarageService"))
local ProfileService = require(Services:WaitForChild("ProfileService"))
local PersonalGarage = require(Services:WaitForChild("PersonalGarage"))
local HousingService = require(Services:WaitForChild("HousingService"))
local RaceService = require(Services:WaitForChild("RaceService"))
local GarageMarketplaceService = require(Services:WaitForChild("GarageMarketplaceService"))
local StartupContract = require(Services:WaitForChild("StartupContract"))

local success, err = pcall(function()
    ProfileService.Start() -- Uses isolated memory-only profiles in unpublished Studio
    WorldService.Start()
    DistrictService.Start()
    HousingService.Start() -- Homes exist before personal vehicle spawn and respawn
    local testCar = VehicleService.Start()
    if testCar then GarageService.Start(testCar) end
    PersonalGarage.Start()
    GarageMarketplaceService.Start()
    RaceService.Start()
    StartupContract.Validate()
    if RunService:IsStudio() then
        require(script.Parent:WaitForChild("dev"):WaitForChild("SmokeTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("ScenarioTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("SimulationTests")).Run()
    end
end)

if not success then
    error("[StreetCity] Failed to start: " .. tostring(err))
end

print("[StreetCity] Prototype server ready; manual multiplayer/physics test required.")
