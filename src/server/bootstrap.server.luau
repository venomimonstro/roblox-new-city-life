--!strict
local RunService = game:GetService("RunService")

local Services = script.Parent:WaitForChild("services")
local WorldService = require(Services:WaitForChild("WorldService"))
local VehicleService = require(Services:WaitForChild("VehicleService"))
local DistrictService = require(Services:WaitForChild("DistrictService"))

local success, err = pcall(function()
    WorldService.Start()
    DistrictService.Start()
    VehicleService.Start()
    if RunService:IsStudio() then
        require(script.Parent:WaitForChild("dev"):WaitForChild("SmokeTests")).Run()
    end
end)

if not success then
    error("[StreetCity] Failed to start: " .. tostring(err))
end

print("[StreetCity] Prototype server ready; manual multiplayer/physics test required.")
