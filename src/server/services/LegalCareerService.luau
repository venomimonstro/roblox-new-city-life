--!strict
-- Production-side legal jobs. Money, waypoints, timing, vehicle ownership and
-- completion all come from the server. No RemoteEvent can award credits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Wallet = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Catalog = require(ReplicatedStorage.Shared:WaitForChild("LegalCareerCatalog"))
local CareerRules = require(ReplicatedStorage.Shared:WaitForChild("CareerRules"))
local Progress = require(ReplicatedStorage.Shared:WaitForChild("SkillProgression"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local ShiftRegistry = require(script.Parent:WaitForChild("WorkShiftRegistry"))
local Career = {}
local running: {[number]: any} = {}
local cooldown: {[number]: number} = {}
local remote: RemoteEvent
local notice: RemoteEvent
local sessionsStarted = 0

local function send(player: Player, job: any?, detail: string?)
    if player.Parent ~= Players then return end
    if not job then
        remote:FireClient(player, nil)
        if detail then notice:FireClient(player, detail) end
        return
    end
    local target = job.definition.stops[job.stage]
    if target then
        remote:FireClient(player, job.definition.title, job.stage,
            #job.definition.stops, target, job.definition.reward,
            job.definition.mode, detail or "Reach the next workplace")
    end
end

local function atPad(player: Player, p: Part): boolean
    if player.Parent ~= Players or not Profile.IsLoaded(player) then return false end
    local char = player.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return human ~= nil and human.Health > 0 and not human.SeatPart
        and root ~= nil and root:IsA("BasePart")
        and (root.Position - p.Position).Magnitude < 13
end

local function transportState(player: Player): boolean
    local char = player.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local seat = human and human.SeatPart
    if not seat or not seat:IsA("VehicleSeat") then return false end
    local car = seat:FindFirstAncestorOfClass("Model")
    if not car or car:GetAttribute("StreetCityVehicle") ~= true
        or car:GetAttribute("OwnerUserId") ~= player.UserId
        or car:GetAttribute("StolenVehicle") == true
        or car:GetAttribute("DriverUserId") ~= player.UserId then return false end
    return seat.Occupant == human
end

local function endMission(player: Player, reason: string)
    local job = running[player.UserId]
    if job then
        running[player.UserId] = nil
        ShiftRegistry.Release(player.UserId, "career_" .. job.definition.id)
        send(player, nil, reason)
    end
end

local function launch(player: Player, definition: any, pad: Part)
    if not atPad(player, pad) then return end
    local id = player.UserId
    local old = running[id]
    if old then
        if old.definition.id == definition.id and old.status == "active" then
            endMission(player, "Shift cancelled; you may accept a new assignment")
        else
            notice:FireClient(player, "Finish your active career mission before starting another")
        end
        return
    end
    if os.clock() < (cooldown[id] or 0) then
        notice:FireClient(player, "Take a short break before your next shift")
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end
    if not ShiftRegistry.Claim(id, "career_" .. definition.id) then
        notice:FireClient(player, "Another work shift is active. Finish or cancel it first.")
        return
    end
    sessionsStarted += 1
    running[id] = {
        definition = definition, status = "active", stage = 1,
        origin = root.Position, lastPosition = root.Position,
        began = os.clock(), moved = 0,
        operation = "career_" .. HttpService:GenerateGUID(false):gsub("-", ""),
        missionId = sessionsStarted,
    }
    send(player, running[id], "Shift started. Visit both marked stops in order.")
end

local function settle(player: Player, job: any)
    local id = player.UserId
    if job.status ~= "active" or running[id] ~= job then return end
    job.status = "settling"
    task.spawn(function()
        local paidAmount = job.definition.reward
        local newLevel = 1
        -- Re-read account lock before write. No mission can pay a second time
        -- while the UpdateAsync request remains unresolved.
        local confirmed = false
        local safe, err = pcall(function()
            confirmed = Profile.Mutate(player, function(profile)
                local xp = Progress.Xp(profile, job.definition.id)
                local amount = Progress.Wage(job.definition.reward, xp)
                if not Wallet.AwardCredits(profile, amount, job.operation) then return false end
                if not Progress.Earn(profile, job.definition.id, 60) then return false end
                Progress.Conduct(profile, 1)
                paidAmount = amount
                newLevel = Progress.Level(Progress.Xp(profile, job.definition.id))
                return true
            end)
        end)
        if not safe then warn("[StreetCity] Career payout failed: " .. tostring(err)) end
        if running[id] ~= job then return end
        running[id] = nil
        ShiftRegistry.Release(id, "career_" .. job.definition.id)
        if confirmed then
            cooldown[id] = os.clock() + 25
            Society.EffectForPlayer(player, "civic", 1)
            send(player, nil, job.definition.title .. ": +"
                .. tostring(paidAmount) .. " credits | skill level " .. tostring(newLevel))
        else
            cooldown[id] = os.clock() + 12
            send(player, nil, "Payment unconfirmed; check saved balance. Never repeat a pending job for a second payment.")
        end
    end)
end

local function advance(player: Player, job: any, now: number, pos: Vector3)
    local definition = job.definition
    local mode = definition.mode
    if job.status ~= "active" then return end
    local validVehicle = transportState(player)
    local isValidTransport = if mode == "vehicle" then validVehicle
        else not (player.Character
            and player.Character:FindFirstChildOfClass("Humanoid")
            and player.Character:FindFirstChildOfClass("Humanoid").SeatPart)
    local prior = job.lastPosition
    local change = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(prior.X, 0, prior.Z)).Magnitude
    job.lastPosition = pos
    -- 0.35s tick at <=150stud/s; jump/teleport spikes do not count.
    if change > 0 and change < 55 and (mode ~= "vehicle" or validVehicle)
        and (mode ~= "foot" or isValidTransport) then
        job.moved += change
    end
    local target = definition.stops[job.stage]
    if not target then return end
    local seconds = now - job.began
    if not CareerRules.CanFinishLeg(job.origin, target, pos, seconds,
        job.moved, mode, isValidTransport) then return end
    if job.stage >= #definition.stops then
        settle(player, job)
        return
    end
    job.stage += 1
    job.origin = pos
    job.lastPosition = pos
    job.began = now
    job.moved = 0
    send(player, job, "Stop confirmed. Proceed to the final workplace.")
end

local function makeStart(root: Instance, definition: any)
    local p = Instance.new("Part")
    p.Name = "CareerStart_" .. definition.id
    p.Size = Vector3.new(6, 1, 6)
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Material = Enum.Material.Neon
    p.Color = if definition.mode == "vehicle"
        then Color3.fromRGB(42, 157, 196) else Color3.fromRGB(78, 186, 122)
    p.Position = definition.start
    p.Parent = root
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "CareerPrompt"
    prompt.ObjectText = definition.title
    prompt.ActionText = "Start / cancel shift"
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = p
    prompt.Triggered:Connect(function(player)
        local ok, err = pcall(launch, player, definition, p)
        if not ok then warn("[StreetCity] Career start: " .. tostring(err)) end
    end)
end

function Career.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local folder = Instance.new("Folder")
    folder.Name = "LegalCareers"
    folder.Parent = world
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    remote = Instance.new("RemoteEvent")
    remote.Name = "StreetCityCareerStatus"
    remote.Parent = ReplicatedStorage
    for _, job in Catalog do makeStart(folder, job) end
    local function connect(player: Player)
        player.CharacterAdded:Connect(function(character)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid and humanoid:IsA("Humanoid") then
                humanoid.Died:Connect(function()
                    endMission(player, "Shift interrupted by hospitalization; start a new job")
                end)
            end
            endMission(player, "Previous mission cancelled after respawn")
        end)
    end
    Players.PlayerAdded:Connect(connect)
    for _, player in Players:GetPlayers() do connect(player) end
    Players.PlayerRemoving:Connect(function(player)
        local job = running[player.UserId]
        if job then ShiftRegistry.Release(player.UserId, "career_" .. job.definition.id) end
        running[player.UserId] = nil
        cooldown[player.UserId] = nil
    end)
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < 0.3 then return end
        accumulator = 0
        local now = os.clock()
        for id, job in pairs(running) do
            if job.status ~= "active" then continue end
            local player = Players:GetPlayerByUserId(id)
            local char = player and player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not player or not Profile.IsLoaded(player)
                or not humanoid or humanoid.Health <= 0
                or not root or not root:IsA("BasePart") then
                if player then endMission(player, "Career shift cancelled") end
                continue
            end
            local safe, err = pcall(advance, player, job, now, root.Position)
            if not safe then
                warn("[StreetCity] Career tick failed for " .. tostring(id) .. ": " .. tostring(err))
                endMission(player, "Mission stopped after an unexpected error")
            end
        end
    end)
    print("[StreetCity] Legal careers ready: " .. tostring(#Catalog) .. " two-stage routes")
end

return Career
