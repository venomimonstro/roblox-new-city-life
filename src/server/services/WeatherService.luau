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
    -- Warm directional daylight, cooler moonlit nights and light haze supply
    -- cinematic depth without GPU-heavy dynamic spotlights on every window.
    Lighting.Ambient = Color3.fromRGB(61, 68, 78)
    Lighting.OutdoorAmbient = Color3.fromRGB(116, 125, 141)
    Lighting.ShadowSoftness = 0.35
    Lighting.EnvironmentDiffuseScale = 0.75
    Lighting.EnvironmentSpecularScale = 0.55
    atmosphere.Color = Color3.fromRGB(206, 218, 231)
    atmosphere.Decay = Color3.fromRGB(122, 145, 176)
    atmosphere.Haze = 1.25
    atmosphere.Glare = 0.07
    local bloom = Lighting:FindFirstChild("StreetCityBloom")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "StreetCityBloom"
        bloom.Intensity = 0.18
        bloom.Size = 17
        bloom.Threshold = 1.55
        bloom.Enabled = false -- enabled only by the high graphics client preset
        bloom.Parent = Lighting
    end
    local rays = Lighting:FindFirstChild("StreetCitySunRays")
    if not rays then
        rays = Instance.new("SunRaysEffect")
        rays.Name = "StreetCitySunRays"
        rays.Intensity = 0.065
        rays.Spread = 0.62
        rays.Enabled = false
        rays.Parent = Lighting
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
