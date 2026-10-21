--!strict
local RunService = game:GetService("RunService")

local Services = script.Parent:WaitForChild("services")
local WorldService = require(Services:WaitForChild("WorldService"))
local VehicleService = require(Services:WaitForChild("VehicleService"))
local DistrictService = require(Services:WaitForChild("DistrictService"))
local GarageService = require(Services:WaitForChild("GarageService"))
local ProfileService = require(Services:WaitForChild("ProfileService"))
local PersonalGarage = require(Services:WaitForChild("PersonalGarage"))
local GarageMarketplaceService = require(Services:WaitForChild("GarageMarketplaceService"))

local success, err = pcall(function()
    if not (RunService:IsStudio() and game.GameId == 0) then
        ProfileService.Start()
    else
        warn("[StreetCity] Unpublished Studio place: persistence disabled")
    end
    WorldService.Start()
    DistrictService.Start()
    local testCar = VehicleService.Start()
    GarageService.Start(testCar)
    PersonalGarage.Start()
    GarageMarketplaceService.Start()
    if RunService:IsStudio() then
        require(script.Parent:WaitForChild("dev"):WaitForChild("SmokeTests")).Run()
    end
end)

if not success then
    error("[StreetCity] Failed to start: " .. tostring(err))
end

print("[StreetCity] Prototype server ready; manual multiplayer/physics test required.")
