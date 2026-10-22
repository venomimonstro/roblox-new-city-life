--!strict
-- Server-authorized prototype jobs and fishing. Clients cannot pick rewards,
-- completion time or destination. Non-real-money currency only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CareerRules = require(ReplicatedStorage.Shared:WaitForChild("CareerRules"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Jobs = {}
local active: {[number]: any} = {}
local cooldown: {[number]: number} = {}
local catches: {[number]: number} = {}
local fishingReady: {[number]: number} = {}
local notice: RemoteEvent

local definitions = {
    {id="taxi", title="Taxi Driver", start=Vector3.new(45, 2, -18),
        finish=Vector3.new(100, 2, -100), reward=170, minimum=25, driving=true},
    {id="firefighter", title="Firefighter", start=Vector3.new(115, 2, -18),
        finish=Vector3.new(200, 2, -100), reward=220, minimum=28},
    {id="police", title="Police Patrol", start=Vector3.new(150, 2, 18),
        finish=Vector3.new(200, 2, 100), reward=200, minimum=30},
    {id="cleaner", title="Street Cleaner", start=Vector3.new(-45, 2, -18),
        finish=Vector3.new(-100, 2, -100), reward=120, minimum=22},
    {id="office", title="Office Clerk", start=Vector3.new(-85, 2, 40),
        finish=Vector3.new(-100, 2, 100), reward=150, minimum=32},
}

local function message(player: Player, value: string)
    if player.Parent == Players then notice:FireClient(player, value) end
end

local function validPlayer(player: Player, position: Vector3): boolean
    if player.Parent ~= Players or not ProfileService.IsLoaded(player) then return false end
    local character = player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return human ~= nil and human.Health > 0 and root ~= nil
        and root:IsA("BasePart") and (root.Position - position).Magnitude <= 15
end

local function pad(parent: Instance, name: string, position: Vector3,
    title: string, action: string, color: Color3, callback: (Player) -> ())
    local p = Instance.new("Part")
    p.Name = name
    p.Size = Vector3.new(6, 1, 6)
    p.Position = position
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = title
    prompt.ActionText = action
    prompt.MaxActivationDistance = 11
    prompt.RequiresLineOfSight = false
    prompt.Parent = p
    prompt.Triggered:Connect(function(player)
        if not validPlayer(player, position) then return end
        local ok, err = pcall(callback, player)
        if not ok then warn("[StreetCity] Job failed: " .. tostring(err)) end
    end)
    return p
end

local function credit(player: Player, amount: number): boolean
    local operation = "job_" .. HttpService:GenerateGUID(false):gsub("-", "")
    return ProfileService.Mutate(player, function(profile)
        return Rules.AwardCredits(profile, amount, operation)
    end)
end

function Jobs.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    local root = Instance.new("Folder")
    root.Name = "CityJobs"
    root.Parent = world
    for _, def in definitions do
        pad(root, "JobStart_" .. def.id, def.start, def.title,
            "Start shift", Color3.fromRGB(45, 178, 173), function(player)
                local id = player.UserId
                if active[id] then
                    message(player, "Finish your existing job first")
                    return
                end
                if os.clock() < (cooldown[id] or 0) then return end
                local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if not rootPart or not rootPart:IsA("BasePart") then return end
                active[id] = {id = def.id, began = os.clock(),
                    origin = rootPart.Position, lastPosition = rootPart.Position,
                    moved = 0, settling = false}
                message(player, def.title .. " started. Travel to the marked workplace.")
            end)
        pad(root, "JobFinish_" .. def.id, def.finish, def.title,
            "Complete shift", Color3.fromRGB(83, 193, 96), function(player)
                local id = player.UserId
                local shift = active[id]
                if not shift or shift.id ~= def.id then
                    message(player, "Start this job first")
                    return
                end
                if shift.settling then return end
                local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if not rootPart or not rootPart:IsA("BasePart") then return end
                if os.clock() - shift.began < def.minimum
                    or not CareerRules.CanFinishLeg(shift.origin, def.finish,
                        rootPart.Position, os.clock() - shift.began,
                        shift.moved, if def.driving then "vehicle" else "foot", true) then
                    message(player, "Workplace route incomplete. You must actually travel between locations.")
                    return
                end
                if def.driving then
                    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    local seat = human and human.SeatPart
                    if not seat or not seat:IsA("VehicleSeat")
                        or not seat:FindFirstAncestorOfClass("Model")
                        or seat:FindFirstAncestorOfClass("Model"):GetAttribute("OwnerUserId") ~= id
                        or seat.Occupant ~= human then
                        message(player, "Taxi mission requires driving a city vehicle")
                        return
                    end
                end
                shift.settling = true
                local paid = credit(player, def.reward)
                if active[id] ~= shift then return end
                if paid then
                    active[id] = nil
                    cooldown[id] = os.clock() + 25
                    message(player, def.title .. ": +" .. tostring(def.reward) .. " credits")
                else
                    active[id] = nil
                    cooldown[id] = os.clock() + 20
                    message(player, "Payment unconfirmed; check saved balance before another shift")
                end
            end)
    end
    local shore = Vector3.new(20, 2, 466)
    local market = Vector3.new(20, 2, 408)
    pad(root, "Fish_Cast", shore, "Fishing Pier",
        "Cast fishing line", Color3.fromRGB(51, 139, 191), function(player)
            local id = player.UserId
            if fishingReady[id] then
                message(player, "Line already cast, return for your catch")
                return
            end
            fishingReady[id] = os.clock() + 14
            message(player, "Fishing started. Wait at least 14 seconds.")
        end)
    pad(root, "Fish_Catch", shore + Vector3.new(9, 0, 0), "Fishing Pier",
        "Collect fish", Color3.fromRGB(52, 118, 183), function(player)
            local id = player.UserId
            local ready = fishingReady[id]
            if not ready or os.clock() < ready then
                message(player, "Cast your line, then wait for a bite")
                return
            end
            fishingReady[id] = nil
            catches[id] = math.min(8, (catches[id] or 0) + 1)
            message(player, "Fish caught! Bring it to the fish market.")
        end)
    pad(root, "Fish_Sell", market, "Fish Market",
        "Sell catch", Color3.fromRGB(95, 172, 119), function(player)
            local id = player.UserId
            local count = catches[id] or 0
            if count < 1 then
                message(player, "Catch fish first at the pier")
                return
            end
            local paid = credit(player, count * 85)
            if paid then
                catches[id] = nil
                message(player, "Sold " .. count .. " fish for " .. (count * 85) .. " credits")
            else
                message(player, "Sale unavailable. Your catch is still in this session.")
            end
        end)
    local sample = 0
    RunService.Heartbeat:Connect(function(dt)
        sample += dt
        if sample < 0.3 then return end
        sample = 0
        for id, shift in pairs(active) do
            if shift.settling then continue end
            local player = Players:GetPlayerByUserId(id)
            local root = player and player.Character
                and player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                local pos = root.Position
                local delta = (Vector3.new(pos.X, 0, pos.Z)
                    - Vector3.new(shift.lastPosition.X, 0, shift.lastPosition.Z)).Magnitude
                shift.lastPosition = pos
                local validMode = true
                if shift.id == "taxi" then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    local seat = humanoid and humanoid.SeatPart
                    local model = seat and seat:FindFirstAncestorOfClass("Model")
                    validMode = seat ~= nil and seat:IsA("VehicleSeat")
                        and model ~= nil and model:GetAttribute("OwnerUserId") == id
                        and seat.Occupant == humanoid
                end
                if delta > 0 and delta < 55 and validMode then shift.moved += delta end
            end
        end
    end)
    local function onCharacter(player: Player, character: Model)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid and humanoid:IsA("Humanoid") then
            humanoid.Died:Connect(function()
                active[player.UserId] = nil
            end)
        end
    end
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
    end)
    for _, player in Players:GetPlayers() do
        player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
        if player.Character then task.spawn(onCharacter, player, player.Character) end
    end
    Players.PlayerRemoving:Connect(function(player)
        local id = player.UserId
        active[id] = nil
        cooldown[id] = nil
        catches[id] = nil -- V1 session-only fish; persistent catch inventory is future work
        fishingReady[id] = nil
    end)
    print("[StreetCity] City jobs ready: 5 services plus fishing and fish market")
end

return Jobs
