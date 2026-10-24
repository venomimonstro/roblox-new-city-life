--!strict
-- Studio-only client E2E receipt: validates interfaces actually created by
-- LocalScripts on two independent clients. Never runs in published servers.
local RunService = game:GetService("RunService")
if RunService:IsStudio() then
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("StreetCityClientTestReceipt", 45)
        if not remote or not remote:IsA("RemoteEvent") then return end
        local pg = player:WaitForChild("PlayerGui", 35)
        if not pg then return end
        local hud = pg:WaitForChild("StreetCityHUD", 35)
        local map = pg:WaitForChild("StreetCityMapAndQuality", 35)
        if not hud or not map then return end
        local requiredHud = {"PlayerSummary", "CareerNavigator", "WantedBoard"}
        for _, name in requiredHud do
            if not hud:FindFirstChild(name, true) then
                warn("[StreetCity Client Acceptance] Missing " .. name)
                return
            end
        end
        local camera = workspace.CurrentCamera
        if not camera or camera.ViewportSize.X < 100 or camera.ViewportSize.Y < 100 then
            warn("[StreetCity Client Acceptance] Missing real viewport")
            return
        end
        print("[StreetCity Client Acceptance] PASS: actual local HUD, minimap, navigation, wanted board")
        remote:FireServer("STREET_CITY_RELEASE_AUTOMATION_V1", true)
    end)
end
