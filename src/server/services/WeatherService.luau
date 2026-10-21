--!strict
-- Shared day/night, clouds, atmospheric fog and weather state.
-- Server advances the clock; clients render their own lightweight rain particles.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weather = {}
local MODES = {"Clear", "Overcast", "Rain", "Storm", "Fog"}
local modeIndex = 1

function Weather.Start()
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "CityAtmosphere"
        atmosphere.Parent = Lighting
    end
    local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
    if not clouds then
        clouds = Instance.new("Clouds")
        clouds.Name = "CityClouds"
        clouds.Parent = workspace.Terrain
    end
    local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not correction then
        correction = Instance.new("ColorCorrectionEffect")
        correction.Name = "CityWeatherGrade"
        correction.Parent = Lighting
    end
    local clock = 7.5
    local nextWeatherAt = os.clock() + 180
    local function apply(mode: string)
        ReplicatedStorage:SetAttribute("StreetCityWeather", mode)
        if mode == "Clear" then
            clouds.Cover, clouds.Density = 0.15, 0.23
            atmosphere.Density = 0.27
            correction.Contrast = 0.04
            correction.Saturation = 0.06
        elseif mode == "Overcast" then
            clouds.Cover, clouds.Density = 0.78, 0.62
            atmosphere.Density = 0.36
            correction.Contrast = -0.06
            correction.Saturation = -0.15
        elseif mode == "Rain" then
            clouds.Cover, clouds.Density = 0.88, 0.75
            atmosphere.Density = 0.41
            correction.Contrast = -0.09
            correction.Saturation = -0.18
        elseif mode == "Storm" then
            clouds.Cover, clouds.Density = 1, 0.9
            atmosphere.Density = 0.46
            correction.Contrast = -0.14
            correction.Saturation = -0.3
        else
            clouds.Cover, clouds.Density = 0.43, 0.48
            atmosphere.Density = 0.66
            correction.Contrast = -0.08
            correction.Saturation = -0.16
        end
        Lighting.Brightness = if mode == "Storm" then 1.2 else 2
    end
    apply("Clear")
    Lighting.ClockTime = clock
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 1 then return end
        local delta = acc
        acc = 0
        -- 24 in-game hours per 48 real minutes.
        clock = (clock + delta / 120) % 24
        Lighting.ClockTime = clock
        if os.clock() >= nextWeatherAt then
            modeIndex = modeIndex % #MODES + 1
            apply(MODES[modeIndex])
            nextWeatherAt = os.clock() + 180
        end
    end)
    print("[StreetCity] Weather and 48-minute day/night cycle active")
end

return Weather
