--!strict
-- LOD NPC life: all 28 residents have low-frequency abstract schedules,
-- and only those near active players receive visual state updates.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("NpcLifeRules"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Service = {}
local records: {any} = {}
local actions = {
    argument = true, social_drinking = true, wedding = true,
    met_someone = true, new_job = true, commute = true,
    shopping = true, hobby = true,
}

local function nearPlayer(position: Vector3, maxDistance: number): boolean
    for _, player in Players:GetPlayers() do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart")
            and (root.Position - position).Magnitude < maxDistance then
            return true
        end
    end
    return false
end

function Service.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local citizens = world:WaitForChild("CityPedestrians")
    local serial = 0
    for _, district in Districts do
        for index = 1, 4 do
            local model = citizens:FindFirstChild("Resident_" .. district.id .. "_" .. index)
            if model and model:IsA("Model") then
                serial += 1
                local life = Rules.New(serial, district.id)
                model:SetAttribute("Occupation", life.occupation)
                model:SetAttribute("Mood", life.mood)
                model:SetAttribute("Married", life.married)
                model:SetAttribute("HasPrivateCar", life.hasCar)
                table.insert(records, {model = model, life = life, time = 0})
            end
        end
    end
    assert(#records == 28, "[StreetCity] Missing NPC lives for seven districts")
    task.spawn(function()
        while true do
            task.wait(12)
            for _, record in records do
                local model = record.model
                if not model.Parent or not model.PrimaryPart then continue end
                record.time += 1
                local state = Society.GetState(record.life.district)
                local safety = if state and type(state.safety) == "number"
                    then state.safety else 55
                local previousEvent = record.life.event
                local event = Rules.Advance(record.life, record.time, safety)
                -- Always advance the social timeline cheaply, even offscreen.
                -- Nearby residents show more detailed attributes / encounters;
                -- distant residents use abstract state only, no physics or pathfinding.
                local close = nearPlayer(model.PrimaryPart.Position, 165)
                model:SetAttribute("NpcLOD", if close then "near" else "abstract")
                if close then
                    model:SetAttribute("Occupation", record.life.occupation)
                    model:SetAttribute("Mood", record.life.mood)
                    model:SetAttribute("LifeEvent", event)
                    model:SetAttribute("Married", record.life.married)
                    model:SetAttribute("Drunk", record.life.drunk)
                    if actions[event] and event ~= previousEvent then
                        model:SetAttribute("LifePauseUntil", os.clock() + 2)
                    end
                end
            end
        end
    end)
    print("[StreetCity] NPC simulated lives ready: " .. #records
        .. " residents, 12-second abstract updates with near-player detail")
end

return Service
