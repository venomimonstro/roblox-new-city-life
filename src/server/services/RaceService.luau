--!strict
-- V1 closed-course solo time trial: server-position checks and bounded credit reward.
-- No client-submitted checkpoint, finish time, distance, or reward amount.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local PersonalGarage = require(script.Parent:WaitForChild("PersonalGarage"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))

local RaceService = {}
local START = Vector3.new(0, 1, 23)
local POINTS = {
    Vector3.new(0, 1, 100),
    Vector3.new(200, 1, 100),
    Vector3.new(200, 1, -100),
    Vector3.new(200, 1, 0),
    Vector3.new(0, 1, 0),
    START,
}
local RADIUS = 22
local MAX_SPEED = 145 -- studs/s, deliberately generous compared with provisional chassis
local REWARD = 650
local states: {[number]: any} = {}
local cooldown: {[number]: number} = {}
local notice: RemoteEvent

local function message(player: Player, value: string)
    if player.Parent == Players then notice:FireClient(player, value) end
end

local function seatedInOwnedCar(player: Player, car: any): boolean
    if not car or not car.Model.Parent then return false end
    if car.Model:GetAttribute("OwnerUserId") ~= player.UserId then return false end
    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return human ~= nil and car.Seat.Occupant == human and human.Health > 0
end

local function cancel(player: Player, reason: string)
    states[player.UserId] = nil
    message(player, reason)
end

function RaceService.Start()
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    local start = Instance.new("Part")
    start.Name = "TimeTrialStart"
    start.Size = Vector3.new(7, 2, 7)
    start.Position = START
    start.Anchored = true
    start.CanCollide = false
    start.Material = Enum.Material.Neon
    start.Color = Color3.fromRGB(85, 206, 122)
    start.Parent = root
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Start solo time trial"
    prompt.ObjectText = "Street City Circuit"
    prompt.MaxActivationDistance = 18
    prompt.RequiresLineOfSight = false
    prompt.Parent = start
    prompt.Triggered:Connect(function(player: Player)
        if states[player.UserId] then return end
        local now = os.clock()
        if (cooldown[player.UserId] or 0) > now then return end
        if not ProfileService.IsLoaded(player) then return end
        local car = PersonalGarage.GetActive(player)
        if not seatedInOwnedCar(player, car) then
            message(player, "Enter your own car to race")
            return
        end
        local pos = car.Chassis.Position
        if (pos - START).Magnitude > 26 then return end
        cooldown[player.UserId] = now + 15
        states[player.UserId] = {
            car = car, checkpoint = 1, began = now, last = now,
            position = pos, checkpointAt = now, checkpointPosition = START,
        }
        message(player, "Time trial started! Checkpoint 1/" .. tostring(#POINTS))
    end)
    for index, position in POINTS do
        local marker = Instance.new("Part")
        marker.Name = "CircuitCheckpoint_" .. index
        marker.Size = Vector3.new(18, 0.6, 18)
        marker.Position = Vector3.new(position.X, -0.2, position.Z)
        marker.Anchored = true
        marker.CanCollide = false
        marker.CanTouch = false
        marker.Transparency = 0.3
        marker.Material = Enum.Material.Neon
        marker.Color = Color3.fromRGB(228, 183, 69)
        marker.Parent = root
    end

    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < 0.1 then return end
        accumulator = 0
        local now = os.clock()
        for id, run in pairs(states) do
            local player = Players:GetPlayerByUserId(id)
            if not player then
                states[id] = nil
                continue
            end
            local car = run.car
            if not seatedInOwnedCar(player, car) or PersonalGarage.GetActive(player) ~= car then
                cancel(player, "Race cancelled: car changed")
                continue
            end
            local pos = car.Chassis.Position
            local delta = now - run.last
            if now - run.began > 180 or delta <= 0 or (pos - run.position).Magnitude > MAX_SPEED * delta + 10
                or car.Chassis.AssemblyLinearVelocity.Magnitude > MAX_SPEED then
                cancel(player, "Race cancelled: invalid driving path")
                continue
            end
            run.last = now
            run.position = pos
            local target = POINTS[run.checkpoint]
            if target and (pos - target).Magnitude <= RADIUS then
                local segmentLength = (target - run.checkpointPosition).Magnitude
                local segmentTime = now - run.checkpointAt
                if segmentTime < segmentLength / MAX_SPEED then
                    cancel(player, "Race cancelled: checkpoint reached too fast")
                    continue
                end
                run.checkpointAt = now
                run.checkpointPosition = target
                run.checkpoint += 1
                if run.checkpoint <= #POINTS then
                    message(player, "Checkpoint " .. tostring(run.checkpoint) .. "/" .. tostring(#POINTS))
                else
                    states[id] = nil
                    if now - run.began < 9 then
                        message(player, "Race time invalid")
                        continue
                    end
                    local operation = "race_" .. HttpService:GenerateGUID(false):gsub("-", "")
                    local granted = ProfileService.Mutate(player, function(profile)
                        return Rules.AwardCredits(profile, REWARD, operation)
                    end)
                    message(player, if granted then ("Finished! +" .. REWARD .. " credits")
                        else "Race finished; credit save unavailable")
                end
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        states[player.UserId] = nil
        cooldown[player.UserId] = nil
    end)
end
return RaceService
