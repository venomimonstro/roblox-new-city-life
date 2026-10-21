--!strict
-- Bounded ambient car agents. All driving authority stays on server; vehicles
-- are stealable only while the artificial driver is controlling an unowned car.
local RunService = game:GetService("RunService")
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Traffic = {}
local agents: {any} = {}
local CATALOG = {
    "starter_american_sedan", "starter_american_pickup",
    "starter_american_muscle", "street_coupe", "sport_sedan",
}

local function route(distance: number): {Vector3}
    return {
        Vector3.new(distance, 3.5, distance),
        Vector3.new(distance, 3.5, -distance),
        Vector3.new(-distance, 3.5, -distance),
        Vector3.new(-distance, 3.5, distance),
    }
end

local function mannequin(car: any, police: boolean)
    local parts = {}
    for index, offset in {
        CFrame.new(0, 1.85, 0), CFrame.new(0, 2.78, 0),
    } do
        local item = Instance.new("Part")
        item.Name = if index == 1 then "NPCDriverBody" else "NPCDriverHead"
        item.Size = if index == 1 then Vector3.new(1.2, 1.25, 0.9)
            else Vector3.new(0.75, 0.75, 0.75)
        item.Shape = if index == 1 then Enum.PartType.Block else Enum.PartType.Ball
        item.Color = if police then Color3.fromRGB(35, 49, 98)
            else Color3.fromRGB(97 + index * 30, 95, 105)
        item.CanCollide = false
        item.CanQuery = false
        item.Massless = true
        item.Anchored = false
        item.CFrame = car.Seat.CFrame * offset
        item.Parent = car.Model
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = car.Chassis
        weld.Part1 = item
        weld.Parent = item
        table.insert(parts, item)
    end
    car.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        if car.Seat.Occupant then
            for _, item in parts do item.Transparency = 1 end
        end
    end)
end

local function createAgent(waypoints: {Vector3}, segment: number,
    catalogId: string, police: boolean): any?
    local destination = waypoints[segment]
    local previous = waypoints[(segment - 2) % #waypoints + 1]
    local midpoint = (destination + previous) * 0.5
    local facing = (destination - previous).Unit
    -- Factory LookVector = (-sin(yaw),0,-cos(yaw)).
    local yaw = math.atan2(-facing.X, -facing.Z)
    local car = VehicleService.SpawnTrafficVehicle(catalogId, midpoint, yaw, police)
    if not car then return nil end
    mannequin(car, police)
    return {
        car = car, points = waypoints, nextIndex = segment,
        police = police, lastPos = midpoint,
        stuckAt = os.clock(), stolenAt = nil,
    }
end

local function updateAgent(agent: any)
    local car = agent.car
    if not car.Model.Parent then return "remove" end
    if car.Model:GetAttribute("TrafficNPC") ~= true then
        if car.Seat.Occupant then
            agent.stolenAt = nil
        else
            agent.stolenAt = agent.stolenAt or os.clock()
            if os.clock() - agent.stolenAt > 150 then
                VehicleService.Despawn(car)
                return "remove"
            end
        end
        return "stolen"
    end
    local position = car.Chassis.Position
    if position.Y < -15 then
        VehicleService.Despawn(car)
        return "remove"
    end
    if (position - agent.lastPos).Magnitude > 5 then
        agent.lastPos = position
        agent.stuckAt = os.clock()
    elseif os.clock() - agent.stuckAt > 35 then
        VehicleService.Despawn(car)
        return "remove"
    end

    local target = agent.points[agent.nextIndex]
    if agent.police then
        local suspect = Wanted.ClosestWanted(position, 450)
        if suspect and suspect.Character then
            local root = suspect.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then target = root.Position end
        end
    end
    local displacement = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
    if displacement.Magnitude < 22 then
        agent.nextIndex = agent.nextIndex % #agent.points + 1
        target = agent.points[agent.nextIndex]
        displacement = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
    end
    if displacement.Magnitude < 0.01 then
        VehicleService.SetTrafficControls(car, 0, 0)
        return "driving"
    end
    local aim = displacement.Unit
    local forward = car.Chassis.CFrame.LookVector
    local flat = Vector3.new(forward.X, 0, forward.Z)
    if flat.Magnitude < 0.01 then return "driving" end
    flat = flat.Unit
    local cross = flat:Cross(aim).Y
    local dot = math.clamp(flat:Dot(aim), -1, 1)
    local steer = math.clamp(-cross * 2.2, -1, 1)
    if dot < -0.2 then steer = if cross > 0 then -1 else 1 end
    VehicleService.SetTrafficControls(car, if dot < 0.6 then 0.22 else 0.48, steer)
    return "driving"
end

function Traffic.Start()
    local inner = route(100)
    local outer = route(200)
    for i = 1, 4 do
        local a = createAgent(inner, i, CATALOG[i], false)
        if a then table.insert(agents, a) end
        local b = createAgent(outer, i, CATALOG[(i % #CATALOG) + 1], false)
        if b then table.insert(agents, b) end
    end
    for i = 1, 2 do
        local p = createAgent(if i == 1 then inner else outer, i,
            "sport_sedan", true)
        if p then table.insert(agents, p) end
    end
    local accum = 0
    RunService.Heartbeat:Connect(function(dt)
        accum += dt
        if accum < 0.2 then return end
        accum = 0
        for index = #agents, 1, -1 do
            local agent = agents[index]
            local ok, status = pcall(updateAgent, agent)
            if not ok then
                warn("[StreetCity] Traffic agent failed: " .. tostring(status))
            elseif status == "remove" then
                table.remove(agents, index)
            end
        end
    end)
    print("[StreetCity] Ambient traffic prototype active: " .. tostring(#agents) .. " cars")
end

return Traffic
