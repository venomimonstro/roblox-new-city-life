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
local WantedService = require(Services:WaitForChild("WantedService"))
local DistrictSocietyService = require(Services:WaitForChild("DistrictSocietyService"))
local FactionService = require(Services:WaitForChild("FactionService"))
local PropertyMarketService = require(Services:WaitForChild("PropertyMarketService"))
local TrafficService = require(Services:WaitForChild("TrafficService"))
local CitizenService = require(Services:WaitForChild("CitizenService"))
local CityJobsService = require(Services:WaitForChild("CityJobsService"))
local WeatherService = require(Services:WaitForChild("WeatherService"))
local CrimeEconomyService = require(Services:WaitForChild("CrimeEconomyService"))
local LifestyleService = require(Services:WaitForChild("LifestyleService"))
local ArmoryService = require(Services:WaitForChild("ArmoryService"))
local RaceService = require(Services:WaitForChild("RaceService"))
local GarageMarketplaceService = require(Services:WaitForChild("GarageMarketplaceService"))
local StartupContract = require(Services:WaitForChild("StartupContract"))

local success, err = pcall(function()
    ProfileService.Start() -- Uses isolated memory-only profiles in unpublished Studio
    WantedService.Start()
    DistrictSocietyService.Start() -- incidents affect local population, safety and property index
    WorldService.Start()
    WeatherService.Start()
    DistrictService.Start()
    HousingService.Start() -- Homes exist before personal vehicle spawn and respawn
    local testCar = VehicleService.Start()
    if testCar then GarageService.Start(testCar) end
    PersonalGarage.Start()
    GarageMarketplaceService.Start()
    RaceService.Start()
    CityJobsService.Start()
    CrimeEconomyService.Start()
    PropertyMarketService.Start()
    FactionService.Start()
    LifestyleService.Start()
    CitizenService.Start()
    ArmoryService.Start()
    TrafficService.Start()
    StartupContract.Validate()
    if RunService:IsStudio() then
        require(script.Parent:WaitForChild("dev"):WaitForChild("SmokeTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("ScenarioTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("SimulationTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("CityLifeTests")).Run()
    end
end)

if not success then
    error("[StreetCity] Failed to start: " .. tostring(err))
end

print("[StreetCity] Prototype server ready; manual multiplayer/physics test required.")
