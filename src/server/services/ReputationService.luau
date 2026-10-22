--!strict
-- Persistent behavior-based reputation. No self-reported conduct from clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Progress = require(ReplicatedStorage.Shared:WaitForChild("SkillProgression"))
local Reputation = {}
local lastCrime: {[number]: number} = {}

function Reputation.Start()
    Wanted.SetConductHandler(function(player: Player, severity: number)
        local id = player.UserId
        local now = os.clock()
        if now - (lastCrime[id] or -100) < 5 then return end
        lastCrime[id] = now
        task.spawn(function()
            if not Profile.IsLoaded(player) then return end
            local change = -math.clamp(severity * 2, 1, 10)
            local ok, result = pcall(Profile.Mutate, player, function(account)
                return Progress.Conduct(account, change)
            end)
            if not ok then warn("[StreetCity] Reputation failed: " .. tostring(result)) end
        end)
    end)
    Players.PlayerRemoving:Connect(function(player)
        lastCrime[player.UserId] = nil
    end)
end
return Reputation
