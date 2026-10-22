--!strict
local RunService = game:GetService("RunService")

local Services = script.Parent:WaitForChild("services", 10)
assert(Services, "[StreetCity Boot] Missing server/services folder (Rojo mapping broken)")
local function loadService(name: string): any
    local module = Services:WaitForChild(name, 10)
    assert(module and module:IsA("ModuleScript"),
        "[StreetCity Boot] Missing ModuleScript: " .. name)
    return require(module)
end
local WorldService = loadService("WorldService")
local StreetDetailService = loadService("StreetDetailService")
local SprintService = loadService("SprintService")
local VehicleService = loadService("VehicleService")
local TransportPhysicsService = loadService("TransportPhysicsService")
local CharacterPhysicsService = loadService("CharacterPhysicsService")
local DistrictService = loadService("DistrictService")
local GarageService = loadService("GarageService")
local ProfileService = loadService("ProfileService")
local PersonalGarage = loadService("PersonalGarage")
local HousingService = loadService("HousingService")
local WantedService = loadService("WantedService")
local DistrictSocietyService = loadService("DistrictSocietyService")
local TerritoryService = loadService("TerritoryService")
local CrewService = loadService("CrewService")
local PropertyService = loadService("PropertyService")
local NatureService = loadService("NatureService")
local BankNetworkService = loadService("BankNetworkService")
local PropertyMarketService = loadService("PropertyMarketService")
local TrafficService = loadService("TrafficService")
local PublicTransitService = loadService("PublicTransitService")
local NpcLifeService = loadService("NpcLifeService")
local CitizenService = loadService("CitizenService")
local CityJobsService = loadService("CityJobsService")
local LegalCareerService = loadService("LegalCareerService")
local WeatherService = loadService("WeatherService")
local ReputationService = loadService("ReputationService")
local TrafficSignalService = loadService("TrafficSignalService")
local DistrictDetailService = loadService("DistrictDetailService")
local CityLandmarkService = loadService("CityLandmarkService")
local CityInfillService = loadService("CityInfillService")
local BoxingService = loadService("BoxingService")
local CrimeEconomyService = loadService("CrimeEconomyService")
local LifestyleService = loadService("LifestyleService")
local ArmoryService = loadService("ArmoryService")
local BountyService = loadService("BountyService")
local LifeAndDeathService = loadService("LifeAndDeathService")
local RaceService = loadService("RaceService")
local GarageMarketplaceService = loadService("GarageMarketplaceService")
local StartupContract = loadService("StartupContract")
local WorldSurfaceAudit = loadService("WorldSurfaceAudit")

local success, err = pcall(function()
    ProfileService.Start() -- Uses isolated memory-only profiles in unpublished Studio
    WantedService.Start()
    DistrictSocietyService.Start() -- incidents affect local population, safety and property index
    ReputationService.Start()
    WorldService.Start()
    StreetDetailService.Start() -- Continuous pedestrian paths, street markings and lamps
    SprintService.Start() -- Server-controlled sprint on desktop, mobile and gamepad
    CharacterPhysicsService.Start() -- Humanoid fall impact and safe landing response
    WeatherService.Start()
    DistrictService.Start()
    DistrictDetailService.Start()
    CityLandmarkService.Start()
    TrafficSignalService.Start()
    HousingService.Start() -- Homes exist before personal vehicle spawn and respawn
    local testCar = VehicleService.Start()
    TransportPhysicsService.Start() -- dedicated cycle, heavy, marine and aviation handling
    if testCar then GarageService.Start(testCar) end
    PersonalGarage.Start()
    GarageMarketplaceService.Start()
    RaceService.Start()
    CityJobsService.Start()
    LegalCareerService.Start()
    CrimeEconomyService.Start()
    PropertyMarketService.Start()
    LifestyleService.Start()
    BoxingService.Start()
    CitizenService.Start()
    NpcLifeService.Start()
    BountyService.Start() -- before armed hits and death settlement
    LifeAndDeathService.Start() -- before first player death
    ArmoryService.Start()
    NatureService.Start()
    CrewService.Start()
    PropertyService.Start()
    TerritoryService.Start()
    BankNetworkService.Start()
    CityInfillService.Start() -- Only occupy free parcels after homes, jobs and shops exist
    TrafficService.Start()
    PublicTransitService.Start()
    WorldSurfaceAudit.Validate() -- fail launch on missing drivable roads or unsafe home surfaces
    StartupContract.Validate()
    if RunService:IsStudio() then
        require(script.Parent:WaitForChild("dev"):WaitForChild("SmokeTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("CityTraversalTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("CityInfillTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("WorldTraversalTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("TrafficSafetyTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("TransitAndNpcTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("VehicleDamageTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("TransportPhysicsTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("ScenarioTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("SimulationTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("CityLifeTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("LegalCareerTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("CareerWorldTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("LifeEconomyTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("DistrictEconomyTests")).Run()
        require(script.Parent:WaitForChild("dev"):WaitForChild("SocialSystemsTests")).Run()
    end
end)

if not success then
    error("[StreetCity] Failed to start: " .. tostring(err))
end

print("[StreetCity] Prototype server ready; manual multiplayer/physics test required.")
