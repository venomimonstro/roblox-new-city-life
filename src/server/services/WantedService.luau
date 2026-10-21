--!strict
-- Server authoritative, non-graphic wanted stars for stylized city gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Wanted = {}
local levels: {[number]: number} = {}
local lastIncident: {[number]: number} = {}
local remote: RemoteEvent? = nil

function Wanted.GetLevel(player: Player): number
    return levels[player.UserId] or 0
end

function Wanted.AddHeat(player: Player, amount: number, _reason: string): number
    if player.Parent ~= Players or type(amount) ~= "number"
        or amount % 1 ~= 0 or amount < 1 or amount > 3 then return 0 end
    local id = player.UserId
    local level = math.clamp((levels[id] or 0) + amount, 0, 5)
    levels[id] = level
    lastIncident[id] = os.clock()
    if remote then remote:FireClient(player, level) end
    return level
end

function Wanted.ClosestWanted(position: Vector3, radius: number): Player?
    local result: Player? = nil
    local closest = radius
    for _, player in Players:GetPlayers() do
        if (levels[player.UserId] or 0) > 0 then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                local distance = (root.Position - position).Magnitude
                if distance < closest then
                    closest = distance
                    result = player
                end
            end
        end
    end
    return result
end

function Wanted.Start()
    remote = Instance.new("RemoteEvent")
    remote.Name = "StreetCityWantedState"
    remote.Parent = ReplicatedStorage
    remote.OnServerEvent:Connect(function(player)
        if remote then remote:FireClient(player, Wanted.GetLevel(player)) end
    end)
    Players.PlayerRemoving:Connect(function(player)
        levels[player.UserId] = nil
        lastIncident[player.UserId] = nil
    end)
    task.spawn(function()
        while true do
            task.wait(20)
            local now = os.clock()
            for _, player in Players:GetPlayers() do
                local id = player.UserId
                local level = levels[id] or 0
                if level > 0 and now - (lastIncident[id] or now) >= 100 then
                    levels[id] = level - 1
                    lastIncident[id] = now
                    if remote then remote:FireClient(player, level - 1) end
                end
            end
        end
    end)
end

return Wanted
