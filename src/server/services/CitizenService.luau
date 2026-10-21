--!strict
-- Lightweight non-graphic procedural residents for seven neighborhoods.
-- Server chooses all payouts and interactions; clients submit no money amounts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Transactions = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Citizens = {}
local actors: {any} = {}
local PALETTE = {
    Color3.fromRGB(73, 110, 153), Color3.fromRGB(146, 96, 72),
    Color3.fromRGB(87, 126, 91), Color3.fromRGB(138, 95, 146),
    Color3.fromRGB(170, 149, 92), Color3.fromRGB(84, 139, 142),
    Color3.fromRGB(122, 109, 96),
}

local function block(model: Model, name: string, size: Vector3,
    offset: CFrame, color: Color3, shape: Enum.PartType?): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = name == "Torso"
    p.Color = color
    p.Shape = shape or Enum.PartType.Block
    p.CFrame = model:GetPivot() * offset
    p.Parent = model
    return p
end

local function createCitizen(parent: Instance, district: any, index: number, districtIndex: number)
    local root = Vector3.new(district.x + 23 + (index - 1) * 13, 2,
        district.z + 26 + (index % 2) * 9)
    local npc = Instance.new("Model")
    npc.Name = "Resident_" .. district.id .. "_" .. tostring(index)
    npc:SetAttribute("District", district.id)
    npc:SetAttribute("Citizen", true)
    local pivot = Instance.new("Part")
    pivot.Name = "Root"
    pivot.Size = Vector3.new(1.1, 2.7, 1)
    pivot.CFrame = CFrame.new(root)
    pivot.Anchored = true
    pivot.Transparency = 1
    pivot.CanCollide = false
    pivot.CanTouch = false
    pivot.CanQuery = false
    pivot.Parent = npc
    npc.PrimaryPart = pivot
    local shirt = PALETTE[(districtIndex + index - 2) % #PALETTE + 1]
    local torso = block(npc, "Torso", Vector3.new(1.6, 2, 0.8),
        CFrame.new(0, 0.45, 0), shirt, nil)
    block(npc, "Head", Vector3.new(0.9, 0.9, 0.9),
        CFrame.new(0, 1.95, 0), Color3.fromRGB(192, 150 + index * 10, 118),
        Enum.PartType.Ball)
    for _, sign in {-1, 1} do
        block(npc, "Arm", Vector3.new(0.45, 1.5, 0.5),
            CFrame.new(sign * 1.03, 0.2, 0), shirt, nil)
        block(npc, "Leg", Vector3.new(0.5, 1.5, 0.5),
            CFrame.new(sign * 0.45, -1.15, 0), Color3.fromRGB(45, 50, 58), nil)
    end
    npc.Parent = parent

    local actor = {
        model = npc, torso = torso, home = root, index = index,
        angle = (index + districtIndex) * 1.7, nextChange = 0,
        pausedUntil = 0, lastRobbed = 0, lastHit = 0,
        districtId = district.id, active = true,
    }
    local rob = Instance.new("ProximityPrompt")
    rob.Name = "RobPrompt"
    rob.ActionText = "Pickpocket"
    rob.ObjectText = "Citizen"
    rob.MaxActivationDistance = 8
    rob.HoldDuration = 1.2
    rob.RequiresLineOfSight = false
    rob.Parent = torso
    rob.Triggered:Connect(function(player: Player)
        local now = os.clock()
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return end
        if player:DistanceFromCharacter(torso.Position) > 10 then return end
        if now - actor.lastRobbed < 90 or not ProfileService.IsLoaded(player) then return end
        actor.lastRobbed = now
        local operation = "npc_" .. HttpService:GenerateGUID(false):gsub("-", "")
        local amount = 35 + (index % 3) * 15
        local awarded = ProfileService.Mutate(player, function(profile)
            return Transactions.AwardCredits(profile, amount, operation)
        end)
        if awarded then
            Wanted.AddHeat(player, 1, "non-graphic theft")
            actor.pausedUntil = now + 8
        end
    end)
    local fight = Instance.new("ProximityPrompt")
    fight.Name = "ShovePrompt"
    fight.ActionText = "Shove"
    fight.ObjectText = "Citizen"
    fight.MaxActivationDistance = 8
    fight.HoldDuration = 0.3
    fight.RequiresLineOfSight = false
    fight.Parent = torso
    fight.Triggered:Connect(function(player: Player)
        local now = os.clock()
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart then return end
        if player:DistanceFromCharacter(torso.Position) > 10 then return end
        if now - actor.lastHit < 15 then return end
        actor.lastHit = now
        actor.pausedUntil = now + 3
        Wanted.AddHeat(player, 1, "street altercation")
        human:TakeDamage(3) -- stylized non-graphic scuffle, not real combat
    end)
    torso.Touched:Connect(function(hit)
        local now = os.clock()
        if now - actor.lastHit < 8 then return end
        local car = hit:FindFirstAncestorOfClass("Model")
        if not car or car:GetAttribute("StreetCityVehicle") ~= true then return end
        if hit.Name ~= "Chassis" or hit.AssemblyLinearVelocity.Magnitude < 35 then return end
        actor.lastHit = now
        actor.pausedUntil = now + 8
        local driverId = car:GetAttribute("DriverUserId")
        if type(driverId) == "number" and driverId > 0 then
            local player = Players:GetPlayerByUserId(driverId)
            if player then Wanted.AddHeat(player, 2, "pedestrian collision") end
        end
    end)
    table.insert(actors, actor)
end

local function adjustPopulation(districtId: string)
    local state = Society.GetState(districtId)
    if not state then return end
    local count = math.min(4, Dynamics.ResidentCount(state))
    for _, actor in actors do
        if actor.districtId == districtId then
            local active = actor.index <= count
            if actor.active ~= active then
                actor.active = active
                for _, descendant in actor.model:GetDescendants() do
                    if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
                        descendant.Transparency = if active then 0 else 1
                    elseif descendant:IsA("ProximityPrompt") then
                        descendant.Enabled = active
                    end
                end
                actor.torso.CanTouch = active
            end
        end
    end
end

-- Cosmetic non-graphic NPC interaction. Server verifies range and line of sight;
-- no client-provided target or damage amount is ever trusted.
function Citizens.HitNearest(player: Player, range: number): boolean
    local character = player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not human or human.Health <= 0 or not root or not root:IsA("BasePart")
        or range < 2 or range > 85 then return false end
    local direction = root.CFrame.LookVector
    local best: any = nil
    local nearest = range
    for _, actor in actors do
        if not actor.active then continue end
        local distance = actor.torso.Position - root.Position
        if distance.Magnitude < nearest and distance.Magnitude > 1
            and direction:Dot(distance.Unit) > 0.15 then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {character, actor.model}
            params.IgnoreWater = true
            local hit = workspace:Raycast(root.Position + Vector3.new(0, 1, 0),
                distance, params)
            if not hit or not hit.Instance.CanCollide then
                nearest = distance.Magnitude
                best = actor
            end
        end
    end
    if not best then return false end
    best.pausedUntil = math.max(best.pausedUntil, os.clock() + 5)
    best.lastHit = os.clock()
    Wanted.AddHeat(player, 1, "stylized NPC fight")
    return true
end

function Citizens.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "CityPedestrians"
    root.Parent = world
    for zoneIndex, district in Districts do
        for index = 1, 4 do
            createCitizen(root, district, index, zoneIndex)
        end
    end
    for _, district in Districts do adjustPopulation(district.id) end
    Society.Changed():Connect(function(districtId: string)
        adjustPopulation(districtId)
    end)
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < 0.25 then return end
        local step = math.min(accumulator, 0.35)
        accumulator = 0
        local now = os.clock()
        for _, actor in actors do
            if actor.active and now >= actor.pausedUntil then
                if now > actor.nextChange then
                    actor.nextChange = now + 3 + actor.index
                    actor.angle += 1.3
                end
                local dir = Vector3.new(math.cos(actor.angle), 0, math.sin(actor.angle))
                local current = actor.model:GetPivot().Position
                local proposed = current + dir * (step * 3.5)
                if (proposed - actor.home).Magnitude > 21 then
                    actor.angle += math.pi
                else
                    actor.model:PivotTo(CFrame.lookAt(proposed, proposed + dir))
                end
            end
        end
    end)
    print("[StreetCity] Neighborhood residents created: " .. tostring(#actors))
end

return Citizens
