--!strict
-- Bounded flora/wildlife assets. Animal hunting is non-graphic and gameplay-only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Nature = {}
local animals: {any} = {}
local lastHunt: {[string]: number} = {}

local function createPart(parent: Instance, name: string, size: Vector3,
    position: Vector3, color: Color3, ball: boolean?, solid: boolean?): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Anchored = true
    p.CanCollide = solid == true
    p.CanQuery = solid == true
    p.CanTouch = false
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    if ball then p.Shape = Enum.PartType.Ball end
    p.Position = position
    p.Parent = parent
    return p
end

local function tree(parent: Instance, place: Vector3, num: number)
    local m = Instance.new("Model")
    m.Name = "Tree_" .. tostring(num)
    m.Parent = parent
    local trunk = createPart(m, "Trunk", Vector3.new(2, 13, 2),
        place + Vector3.new(0, 5.5, 0), Color3.fromRGB(100, 76, 51), false, true)
    trunk.Material = Enum.Material.Wood
    for height = 0, 2 do
        local canopy = createPart(m, "Leaves", Vector3.new(11 - height * 2.5, 6, 11 - height * 2.5),
            place + Vector3.new(0, 11 + height * 3.8, 0),
            Color3.fromRGB(40 + height * 7 + num % 12, 102 + num % 28, 52), true, false)
        canopy.Material = Enum.Material.Grass
    end
end

local function animal(parent: Instance, district: any, index: number): any
    local species = ({"Deer", "Fox", "Hare"})[index]
    local color = if index == 1 then Color3.fromRGB(136, 96, 57)
        elseif index == 2 then Color3.fromRGB(171, 92, 49)
        else Color3.fromRGB(132, 121, 107)
    local home = Vector3.new(math.floor(district.x / 100) * 100 + 25 + (index - 1) * 100,
        1.2, math.floor(district.z / 100) * 100 + 25)
    local model = Instance.new("Model")
    model.Name = species .. "_" .. district.id
    model:SetAttribute("WildAnimal", true)
    model:SetAttribute("District", district.id)
    model.Parent = parent
    local body = createPart(model, "Body", Vector3.new(2.9, 1.1, 1.45),
        home, color, true, false)
    model.PrimaryPart = body
    createPart(model, "Head", Vector3.new(0.9, 0.9, 0.9),
        home + Vector3.new(1.65, 0.65, 0), color, true, false)
    for _, x in {-0.75, 0.75} do
        for _, z in {-0.45, 0.45} do
            createPart(model, "Leg", Vector3.new(0.3, 0.95, 0.32),
                home + Vector3.new(x, -0.85, z), color, false, false)
        end
    end
    local obj = {
        model = model, district = district.id, index = index,
        home = home, nextMove = 0, angle = index * 2,
        hiddenUntil = 0, visible = true,
    }
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "WildlifeHunt"
    prompt.ActionText = "Hunt (non-graphic)"
    prompt.ObjectText = species
    prompt.MaxActivationDistance = 11
    prompt.HoldDuration = 2
    prompt.RequiresLineOfSight = false
    prompt.Parent = body
    prompt.Triggered:Connect(function(player)
        if not obj.visible or os.clock() < obj.hiddenUntil
            or player:DistanceFromCharacter(body.Position) > 13
            or not Profile.IsLoaded(player) then return end
        local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 or h.SeatPart then return end
        local key = tostring(player.UserId) .. ":" .. model.Name
        if os.clock() - (lastHunt[key] or -1000) < 120 then return end
        lastHunt[key] = os.clock()
        local operation = "hunt_" .. HttpService:GenerateGUID(false):gsub("-", "")
        local amount = 70 + index * 25
        local confirmed = Profile.Mutate(player, function(profile)
            return Rules.AwardCredits(profile, amount, operation)
        end)
        if confirmed then
            obj.hiddenUntil = os.clock() + 100
            prompt.Enabled = false
            -- Trophy/reward is virtual. No real-world hunting assets or gore.
            model:SetAttribute("HuntedUntil", obj.hiddenUntil)
        end
    end)
    return obj
end

function Nature.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "CityNature"
    root.Parent = world
    for _, district in Districts do
        local zone = Instance.new("Folder")
        zone.Name = district.id
        zone.Parent = root
        for n = 1, 12 do
            -- Tree trunks stay 30+ studs from any global x/z road axis.
            local x = math.floor(district.x / 100) * 100
                + (math.floor((n - 1) / 3) - 1) * 100 + 30
            local z = math.floor(district.z / 100) * 100
                + ((n - 1) % 3 - 1) * 100 + 30
            tree(zone, Vector3.new(x, 0.1, z), n)
        end
        for n = 1, 3 do
            table.insert(animals, animal(zone, district, n))
        end
    end
    Society.Changed():Connect(function(districtId, state)
        local target = Dynamics.ResidentCount(state)
        for _, wildlife in animals do
            if wildlife.district == districtId then
                wildlife.visible = wildlife.index <= target
            end
        end
    end)
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.6 then return end
        local step = math.min(acc, 0.8)
        acc = 0
        local now = os.clock()
        for _, obj in animals do
            local visible = obj.visible and now >= obj.hiddenUntil
            for _, child in obj.model:GetChildren() do
                if child:IsA("BasePart") then
                    child.Transparency = if visible then 0 else 1
                elseif child:IsA("ProximityPrompt") then
                    child.Enabled = visible
                end
            end
            local pivot = obj.model.PrimaryPart
            if visible and pivot then
                if now > obj.nextMove then
                    obj.angle += 2.3
                    obj.nextMove = now + 5 + obj.index
                end
                local delta = Vector3.new(math.cos(obj.angle), 0, math.sin(obj.angle))
                local nextPos = pivot.Position + delta * step * 2.5
                if (nextPos - obj.home).Magnitude > 8 then
                    obj.angle += math.pi
                else
                    obj.model:PivotTo(CFrame.lookAt(nextPos, nextPos + delta))
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        local prefix = tostring(player.UserId) .. ":"
        for key in pairs(lastHunt) do
            if string.sub(key, 1, #prefix) == prefix then lastHunt[key] = nil end
        end
    end)
    print("[StreetCity] 84 trees and 21 animated deer/fox/hare wildlife NPCs")
end

return Nature
