--!strict
-- One active personal starter car per player, spawned only from validated profile data.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local PersonalGarage = {}
local active: { [number]: any } = {}
local pending: { [number]: boolean } = {}

local function ownedSpawn(player: Player)
    local id = player.UserId
    if active[id] or pending[id] then return end
    pending[id] = true
    local profile = ProfileService.Read(player)
    if profile and profile.garage and profile.garage.starter then
        local slot = id % 10
        local location = Vector3.new(45 + slot * 14, 4, -80)
        active[id] = VehicleService.SpawnForPlayer(player, profile.garage.starter, location)
    end
    pending[id] = nil
end

function PersonalGarage.Start()
    if RunService:IsStudio() and game.GameId == 0 then
        warn("[StreetCity] PersonalGarage disabled for unpublished Studio place")
        return
    end
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            for _ = 1, 60 do
                if player.Parent ~= Players then return end
                if ProfileService.IsLoaded(player) then
                    ownedSpawn(player)
                    return
                end
                task.wait(0.5)
            end
        end)
    end)
    Players.PlayerRemoving:Connect(function(player)
        local car = active[player.UserId]
        if car then
            VehicleService.Despawn(car)
            active[player.UserId] = nil
        end
        pending[player.UserId] = nil
    end)
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            for _ = 1, 60 do
                if player.Parent ~= Players then return end
                if ProfileService.IsLoaded(player) then
                    ownedSpawn(player)
                    return
                end
                task.wait(0.5)
            end
        end)
    end
end
return PersonalGarage
