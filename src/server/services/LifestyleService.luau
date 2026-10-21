--!strict
-- Food stands, body-shape progression and server-validated sports sessions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Health = {}
local cooldowns: {[number]: number} = {}
local current: {[number]: any} = {}
local notice: RemoteEvent

local function tell(player: Player, text: string)
    if player.Parent == Players then notice:FireClient(player, text) end
end

local function op(): string
    return "life_" .. HttpService:GenerateGUID(false):gsub("-", "")
end

local function applyBody(player: Player)
    local data = Profile.Read(player)
    if not data then return end
    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not human or human.Health <= 0 then return end
    local width = math.clamp(0.93 + data.bodyFat / 400 + data.fitness / 600, 0.95, 1.3)
    for _, key in {"BodyWidthScale", "BodyDepthScale"} do
        local scale = human:FindFirstChild(key)
        if scale and scale:IsA("NumberValue") then scale.Value = width end
    end
    human.WalkSpeed = math.clamp(15 + data.fitness / 35 - data.bodyFat / 45
        + (data.nutrition - 50) / 100, 12, 20)
end

local function pad(root: Instance, key: string, position: Vector3,
    actionText: string, color: Color3, callback: (Player) -> ())
    local part = Instance.new("Part")
    part.Name = key
    part.Size = Vector3.new(7, 0.8, 7)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Position = position
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Parent = root
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = key
    prompt.ActionText = actionText
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 11
    prompt.Parent = part
    prompt.Triggered:Connect(function(player: Player)
        local char = player.Character
        local human = char and char:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart
            or not Profile.IsLoaded(player)
            or player:DistanceFromCharacter(part.Position) > 13 then return end
        local ok, err = pcall(callback, player)
        if not ok then warn("[StreetCity Fitness] " .. key .. ": " .. tostring(err)) end
    end)
end

function Health.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "CityLifestyle"
    root.Parent = world
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent

    for _, food in {
        {id="HotDog", price=55, nutrition=18, fat=2, x=75, z=160},
        {id="Burger", price=90, nutrition=29, fat=4, x=-75, z=-160},
        {id="Salad", price=110, nutrition=30, fat=0, x=275, z=160},
        {id="Sandwich", price=70, nutrition=22, fat=1, x=-275, z=160},
        {id="Coffee", price=35, nutrition=9, fat=1, x=775, z=-260},
    } do
        pad(root, "Food_" .. food.id, Vector3.new(food.x, 2, food.z),
            "Buy and eat (" .. food.price .. " cash)",
            Color3.fromRGB(205, 141, 73), function(player)
                local id = player.UserId
                if os.clock() - (cooldowns[id] or 0) < 3 then return end
                cooldowns[id] = os.clock()
                local operation = op()
                local succeeded = Profile.Mutate(player, function(data)
                    return Rules.EatFood(data, food.price, food.nutrition, food.fat, operation)
                end)
                if succeeded then
                    applyBody(player)
                    tell(player, food.id .. " eaten: energy restored")
                else
                    tell(player, "Not enough cash / food purchase unavailable")
                end
            end)
    end

    for _, sport in {
        {id="Gym", x=120, z=160, finishX=145, finishZ=160, gain=5},
        {id="Boxing", x=-220, z=160, finishX=-245, finishZ=160, gain=4},
        {id="Tennis", x=320, z=-160, finishX=350, finishZ=-160, gain=4},
        {id="Dancing", x=-320, z=-160, finishX=-350, finishZ=-160, gain=3},
        {id="Jogging", x=160, z=320, finishX=160, finishZ=360, gain=3},
    } do
        local start = Vector3.new(sport.x, 2, sport.z)
        local destination = Vector3.new(sport.finishX, 2, sport.finishZ)
        pad(root, "SportStart_" .. sport.id, start, "Start activity",
            Color3.fromRGB(72, 152, 211), function(player)
                local id = player.UserId
                if current[id] then
                    tell(player, "Finish your current activity first")
                    return
                end
                if os.clock() - (cooldowns[id] or 0) < 12 then return end
                current[id] = {id = sport.id, began = os.clock(), start = start}
                tell(player, sport.id .. " started. Practice and finish at the next zone.")
            end)
        pad(root, "SportFinish_" .. sport.id, destination, "Finish activity",
            Color3.fromRGB(79, 194, 150), function(player)
                local id = player.UserId
                local workout = current[id]
                if not workout or workout.id ~= sport.id then return end
                if os.clock() - workout.began < 22 then
                    tell(player, "Activity requires at least 22 seconds")
                    return
                end
                local operation = op()
                local confirmed = Profile.Mutate(player, function(profile)
                    return Rules.Workout(profile, sport.gain, operation)
                end)
                if confirmed then
                    current[id] = nil
                    cooldowns[id] = os.clock()
                    applyBody(player)
                    tell(player, sport.id .. " complete: fitness +" .. sport.gain)
                else
                    tell(player, "Rest and eat before training again")
                end
            end)
    end
    local function onPlayer(player: Player)
        player.CharacterAdded:Connect(function()
            task.spawn(function()
                for _ = 1, 25 do
                    if player.Parent ~= Players then return end
                    if Profile.IsLoaded(player) then
                        task.wait(0.5)
                        applyBody(player)
                        return
                    end
                    task.wait(1)
                end
            end)
        end)
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in Players:GetPlayers() do onPlayer(player) end
    Players.PlayerRemoving:Connect(function(player)
        cooldowns[player.UserId] = nil
        current[player.UserId] = nil
    end)
    print("[StreetCity] Food kiosks, gym, tennis, boxing, dancing and jogging ready")
end

return Health
