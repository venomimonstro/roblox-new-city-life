--!strict
-- Server-authoritative test fleet. Each category has its own force model:
-- road/cycle tyre contact, boat buoyancy, aeroplane lift and stall.
-- This is a first functional physics slice; true hinge suspension and aircraft
-- control surfaces require Studio tuning and authored assets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Specs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TransportSpecs"))
local Factory = require(script.Parent:WaitForChild("VehicleFactory"))
local Transport = {}
local fleet: {[Model]: any} = {}
local lastInput: {[number]: number} = {}
local RESPAWN_SECONDS = 18
local DEPTH = 4.5

local function newVehicle(typeId: string, position: Vector3, heading: number): any?
    local spec = Specs[typeId]
    if not spec then return nil end
    local container = workspace:FindFirstChild("StreetCityTransport")
    if not container then return nil end
    local created = Factory.Create(container, position, heading)
    local model = created.Model
    model.Name = "City " .. typeId
    model:SetAttribute("TransportType", typeId)
    model:SetAttribute("TransportKind", spec.kind)
    model:SetAttribute("StreetCityVehicle", true)
    model:SetAttribute("EngineId", "stock_i4")
    model:SetAttribute("VehicleHealth", 100)
    local root = created.Chassis
    root.Size = if spec.kind == "cycle" then Vector3.new(1.8, 2, 5)
        elseif typeId == "tractor" then Vector3.new(5.4, 3, 8)
        elseif spec.kind == "road" then Vector3.new(7, 3.4, 14)
        elseif spec.kind == "water" then Vector3.new(7, 2.6, 14)
        else Vector3.new(8, 2.8, 18)
    -- The physical core is one rigid assembly; applied force is mass-aware.
    -- Decorative stock coupe panels are hidden until bespoke models arrive.
    for _, descendant in model:GetChildren() do
        if descendant:IsA("BasePart") and descendant ~= root
            and descendant ~= created.Seat then
            descendant.Transparency = 1
        end
    end
    root.Color = if spec.kind == "air" then Color3.fromRGB(196, 206, 213)
        elseif spec.kind == "water" then Color3.fromRGB(50, 127, 173)
        elseif spec.kind == "cycle" then Color3.fromRGB(214, 91, 74)
        else Color3.fromRGB(133, 161, 90)
    local label = created.Seat:FindFirstChildOfClass("ProximityPrompt")
    if label then label.ObjectText = typeId end
    -- Artificial body mass distributed inside the rigid assembly.
    local ballast = Instance.new("Part")
    ballast.Name = "MassBallast"
    ballast.Size = Vector3.new(1, 1, 1)
    ballast.Transparency = 1
    ballast.CanCollide = false
    ballast.CanTouch = false
    ballast.CanQuery = false
    ballast.Anchored = false
    ballast.Massless = false
    ballast.CustomPhysicalProperties = PhysicalProperties.new(
        math.clamp(spec.mass / 20, 0.7, 100), 0.7, 0.05, 100, 100)
    ballast.CFrame = root.CFrame
    ballast.Parent = model
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1 = root, ballast
    weld.Parent = ballast
    pcall(function()
        if root:CanSetNetworkOwnership() then root:SetNetworkOwner(nil) end
    end)
    local state = {
        vehicle = created, kind = spec.kind, spec = spec, input = {throttle=0,steer=0,last=0},
        home = CFrame.new(position) * CFrame.Angles(0, heading, 0),
        respawnAt = 0, previousY=0,
    }
    fleet[model] = state
    created.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local occupant = created.Seat.Occupant
        local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
        model:SetAttribute("DriverUserId", if driver then driver.UserId else 0)
        state.input = {throttle=0,steer=0,last=0}
    end)
    return state
end

local function usePhysics(state: any)
    local car = state.vehicle
    local body = car.Chassis
    if not body:IsDescendantOf(workspace) then return end
    local spec = state.spec
    local occupant = car.Seat.Occupant
    local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
    local live = player ~= nil and occupant.Health > 0
        and os.clock() - state.input.last < 0.5
    local throttle = if live then state.input.throttle else 0
    local steer = if live then state.input.steer else 0
    local velocity = body.AssemblyLinearVelocity
    local flat = Vector3.new(velocity.X, 0, velocity.Z)
    local forward = body.CFrame.LookVector
    local side = body.CFrame.RightVector
    local horizontalSpeed = flat:Dot(forward)
    local speedFactor = math.clamp(1 - math.abs(horizontalSpeed) / spec.speed, 0, 1)
    local mass = body.AssemblyMass
    local force = Vector3.zero
    local suspension = Vector3.zero
    local steering = 0
    if state.kind == "road" or state.kind == "cycle" then
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances = {car.Model}
        ray.IgnoreWater = true
        local count, meanDepth, meanNormal = 0, 0, Vector3.zero
        local halfZ = if state.kind == "cycle" then 1.6 else 4.5
        local halfX = if state.kind == "cycle" then 0.5 else 2.5
        for _, x in {-halfX, halfX} do
            for _, z in {-halfZ, halfZ} do
                local p = body.CFrame:PointToWorldSpace(Vector3.new(x, -0.65, z))
                local hit = workspace:Raycast(p, Vector3.new(0, -DEPTH, 0), ray)
                if hit and hit.Instance.CanCollide and hit.Normal.Y > 0.45 then
                    count += 1
                    meanDepth += hit.Distance
                    meanNormal += hit.Normal
                end
            end
        end
        if count > 0 then
            local compression = math.clamp(1 - meanDepth / (count * DEPTH), 0, 1)
            -- Gravity compensation plus damped spring, capped to prevent launch.
            local lift = math.clamp(compression * 2.5 * workspace.Gravity
                - velocity.Y * 15, 0, workspace.Gravity * 1.25)
            suspension = Vector3.yAxis * (mass * lift)
            force = mass * (forward * (throttle * spec.acceleration * speedFactor)
                - side * velocity:Dot(side) * 1.9 - flat * spec.drag)
            steering = steer * spec.yaw
                * math.clamp(math.abs(horizontalSpeed) / 14, 0, 1)
            -- Two-wheelers receive an approximate lean correction.
            if state.kind == "cycle" then
                local roll = body.CFrame.RightVector.Y
                local upright = math.clamp(roll * -2.6, -1, 1)
                local av = body.AssemblyAngularVelocity
                body.AssemblyAngularVelocity =
                    Vector3.new(av.X, av.Y, av.Z + upright * 0.6)
            end
        else
            force = -flat * mass * spec.drag * 0.25
        end
    elseif state.kind == "water" then
        -- Buoyancy requires actual Terrain water, not arbitrary y=0 land.
        local material = workspace.Terrain:ReadVoxels(
            Region3.new(body.Position - Vector3.new(2, 3, 2),
                body.Position + Vector3.new(2, 3, 2)):ExpandToGrid(4), 4)
        local nearWater = false
        for i = 1, #material do
            for j = 1, #material[i] do
                for k = 1, #material[i][j] do
                    if material[i][j][k] == Enum.Material.Water then nearWater = true end
                end
            end
        end
        if nearWater then
            suspension = Vector3.yAxis * mass
                * math.clamp(workspace.Gravity - velocity.Y * 16, 0, workspace.Gravity * 1.3)
            force = mass * (forward * throttle * spec.acceleration * speedFactor
                - flat * spec.drag * 2 - side * velocity:Dot(side) * 2)
            steering = steer * spec.yaw * math.clamp(math.abs(horizontalSpeed) / 8, 0, 1)
        else
            force = -flat * mass * spec.drag
        end
    elseif state.kind == "air" then
        local airspeed = math.abs(horizontalSpeed)
        local stall = math.clamp((airspeed - 30) / 55, 0, 1)
        -- Lift rises smoothly with airspeed, never creates stationary hovering.
        suspension = body.CFrame.UpVector * mass * workspace.Gravity
            * math.clamp(stall * 1.17, 0, 1.17)
        force = mass * (forward * (math.max(throttle, 0) * spec.acceleration
            * speedFactor) - velocity * spec.drag)
        steering = steer * spec.yaw * stall
    end
    car.SuspensionForce.Force = suspension
    car.DriveForce.Force = force
    car.YawMotor.AngularVelocity = Vector3.yAxis * steering
    if body.Position.Y < -70 and state.respawnAt == 0 then
        state.respawnAt = os.clock() + RESPAWN_SECONDS
    end
    if state.respawnAt > 0 and os.clock() >= state.respawnAt then
        if car.Seat.Occupant then car.Seat.Occupant.Sit = false end
        car.Model:PivotTo(state.home)
        body.AssemblyLinearVelocity = Vector3.zero
        body.AssemblyAngularVelocity = Vector3.zero
        state.respawnAt = 0
    end
end

function Transport.Start()
    local folder = Instance.new("Folder")
    folder.Name = "StreetCityTransport"
    folder.Parent = workspace
    local remotes = ReplicatedStorage:WaitForChild("StreetCityRemotes")
    local input = Instance.new("RemoteEvent")
    input.Name = "TransportInput"
    input.Parent = remotes
    input.OnServerEvent:Connect(function(player: Player, throttle: any, steer: any)
        if type(throttle) ~= "number" or type(steer) ~= "number"
            or throttle ~= throttle or steer ~= steer
            or math.abs(throttle) > 1 or math.abs(steer) > 1 then return end
        local now = os.clock()
        if now - (lastInput[player.UserId] or -10) < 0.045 then return end
        lastInput[player.UserId] = now
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        local seat = humanoid.SeatPart
        local model = seat and seat:FindFirstAncestorOfClass("Model")
        local state = model and fleet[model]
        if not state or seat ~= state.vehicle.Seat or seat.Occupant ~= humanoid then return end
        state.input = {throttle=throttle, steer=steer, last=now}
    end)
    -- Placed near actual roads or coastline; airplane on a reserved airfield.
    for _, site in {
        {id="bicycle",x=200,z=320,y=5,h=0},
        {id="motorcycle",x=300,z=320,y=5,h=0},
        {id="dirtbike",x=-300,z=320,y=5,h=0},
        {id="truck",x=400,z=320,y=6,h=0},
        {id="tractor",x=-400,z=320,y=6,h=0},
        {id="bus",x=500,z=320,y=6,h=0},
        {id="speedboat",x=1000,z=800,y=8,h=0},
        {id="fishingboat",x=1100,z=800,y=8,h=0},
        {id="propplane",x=1200,z=-800,y=12,h=0},
    } do
        local ok, result = pcall(newVehicle, site.id,
            Vector3.new(site.x,site.y,site.z), site.h)
        if not ok or not result then
            warn("[StreetCity] Transport spawn " .. site.id .. " failed: " .. tostring(result))
        end
    end
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 1/30 then return end
        acc = 0
        for model, state in pairs(fleet) do
            if model.Parent then
                local ok, err = pcall(usePhysics, state)
                if not ok then
                    state.vehicle.SuspensionForce.Force = Vector3.zero
                    state.vehicle.DriveForce.Force = Vector3.zero
                    warn("[StreetCity] Transport physics error: " .. tostring(err))
                end
            else fleet[model] = nil end
        end
    end)
    Players.PlayerRemoving:Connect(function(player) lastInput[player.UserId] = nil end)
    print("[StreetCity] Transport class physics initialized")
end

return Transport
