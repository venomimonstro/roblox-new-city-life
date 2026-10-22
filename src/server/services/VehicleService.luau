--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local VehicleMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleMath"))
local Damage = require(ReplicatedStorage.Shared:WaitForChild("VehicleDamageRules"))
local Factory = require(script.Parent:WaitForChild("VehicleFactory"))
local Powertrain = require(ReplicatedStorage.Shared:WaitForChild("Powertrain"))
local VehicleBuild = require(ReplicatedStorage.Shared:WaitForChild("VehicleBuild"))
local VehicleCatalog = require(ReplicatedStorage.Shared:WaitForChild("VehicleCatalog"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Housing = require(script.Parent:WaitForChild("HousingService"))

local VehicleService = {}
local WHEEL_OFFSETS = {
    Vector3.new(-2.1, 0, -3.5), Vector3.new(2.1, 0, -3.5),
    Vector3.new(-2.1, 0, 3.5), Vector3.new(2.1, 0, 3.5),
}
local cars: { Factory.Car } = {}
local cooldown: { [number]: number } = {}
local inputThrottle: { [number]: number } = {}
local inputState: { [Model]: { throttle: number, steer: number, last: number } } = {}
local ownershipConnections: { [Model]: RBXScriptConnection } = {}
local raycastCache: {[Model]: RaycastParams} = {}
local priorVelocity: {[Model]: number} = {}
local priorImpactAt: {[Model]: number} = {}
local driveState: { [Model]: { gear: number, rpm: number, signature: string, spec: any?, lastTelemetry: number } } = {}

local function isDriver(player: Player, car: Factory.Car): boolean
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local ownerId = car.Model:GetAttribute("OwnerUserId")
    return (ownerId == nil or ownerId == player.UserId)
        and humanoid ~= nil and humanoid.Health > 0 and car.Seat.Occupant == humanoid
end

local function assignOwner(car: Factory.Car)
    local occupant = car.Seat.Occupant
    local owner = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
    local ownerId = car.Model:GetAttribute("OwnerUserId")
    if owner and ownerId == nil and car.Model:GetAttribute("TrafficNPC") == true then
        car.Model:SetAttribute("TrafficNPC", false)
        car.Model:SetAttribute("StolenVehicle", true)
        car.Model:SetAttribute("ThiefUserId", owner.UserId)
        Wanted.AddHeat(owner, if car.Model:GetAttribute("IsPolice") then 3 else 1,
            "vehicle theft")
    end
    if occupant and (not owner or (ownerId ~= nil and owner.UserId ~= ownerId)) then
        -- Reject a direct VehicleSeat:Sit/Touch seating attempt immediately,
        -- before this player's first vehicle input or physics tick.
        occupant.Sit = false
        owner = nil
    end
    -- Deliberately server-owned until we complete authoritative race movement checks.
    -- This favors consistent behavior over client-side responsiveness.
    local ok, err = pcall(function()
        if car.Chassis:CanSetNetworkOwnership() then
            car.Chassis:SetNetworkOwner(nil)
        end
    end)
    if not ok then
        warn("[StreetCity] Network ownership update failed: " .. tostring(err))
    end
    inputState[car.Model] = {throttle = 0, steer = 0, last = 0}
    car.Model:SetAttribute("DriverUserId", if owner then owner.UserId else 0)
end

local function updateCar(car: Factory.Car)
    local root = car.Chassis
    local seat = car.Seat
    local cfg = Config.Vehicle
    if not root:IsDescendantOf(workspace) then
        return
    end
    -- Real physics can occasionally tunnel through streamed terrain.
    -- Recover only personally owned cars, never arbitrary NPC/stolen vehicles.
    local ownerUserId = car.Model:GetAttribute("OwnerUserId")
    if root.Position.Y < -40 and type(ownerUserId) == "number"
        and ownerUserId > 0 then
        local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
        local home = ownerPlayer and Housing.GetGarageSpawn(ownerPlayer)
        if home then
            if car.Seat.Occupant then car.Seat.Occupant.Sit = false end
            inputState[car.Model] = {throttle = 0, steer = 0, last = 0}
            car.DriveForce.Force = Vector3.zero
            car.SuspensionForce.Force = Vector3.zero
            car.YawMotor.AngularVelocity = Vector3.zero
            car.Model:PivotTo(CFrame.new(home.position)
                * CFrame.Angles(0, home.heading, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            priorVelocity[car.Model] = nil -- no teleport-induced damage
            car.Model:SetAttribute("StreetCityWorldRescues",
                (car.Model:GetAttribute("StreetCityWorldRescues") or 0) + 1)
            return
        end
    end
    local vel = root.AssemblyLinearVelocity
    local previous = priorVelocity[car.Model]
    local speed = vel.Magnitude
    priorVelocity[car.Model] = speed
    -- Only impacts with a genuine speed discontinuity count, NOT ordinary
    -- acceleration, free fall, a respawn teleport or ground raycast loss.
    if previous and car.Model:GetAttribute("VehicleHealth") ~= nil
        and os.clock() - (priorImpactAt[car.Model] or -1000) > 0.9 then
        local impact = Damage.Impact(math.max(0, previous - speed), previous,
            root.Position.Y > -5, seat.Occupant ~= nil)
        if impact.damage > 0 then
            local current = car.Model:GetAttribute("VehicleHealth")
            if type(current) == "number" then
                local nextHealth = math.max(0, current - impact.damage)
                car.Model:SetAttribute("VehicleHealth", nextHealth)
                car.Model:SetAttribute("VehicleCondition", Damage.Status(nextHealth))
                priorImpactAt[car.Model] = os.clock()
                if seat.Occupant and impact.occupantDamage > 0 then
                    seat.Occupant:TakeDamage(impact.occupantDamage)
                end
            end
        end
    end
    local fwd = root.CFrame.LookVector
    local right = root.CFrame.RightVector
    local longitudinal = vel:Dot(fwd)
    local lateral = vel:Dot(right)
    local planar = Vector3.new(vel.X, 0, vel.Z)

    local occupant = seat.Occupant
    local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
    local ownerId = car.Model:GetAttribute("OwnerUserId")
    local authorized = player ~= nil and occupant.Health > 0
        and (ownerId == nil or ownerId == player.UserId)
    if occupant and not authorized then
        -- Exploit-resistant even if another script seats a non-owner directly.
        occupant.Sit = false
    end
    local input = inputState[car.Model]
    local npcDriving = occupant == nil and car.Model:GetAttribute("TrafficNPC") == true
    local live = (authorized or npcDriving) and input ~= nil
        and os.clock() - input.last < (if npcDriving then 0.8 else 0.45)
    local health = car.Model:GetAttribute("VehicleHealth")
    local driveFactor = if type(health) == "number" then Damage.DriveFactor(health) else 1
    local drive = if live then input.throttle * driveFactor else 0
    local steer = if live then input.steer else 0
    -- Early simulation integration: gear ratios affect drive acceleration. The chassis
    -- is still arcade physics; wheel/suspension constraints are a later milestone.
    local engineId = car.Model:GetAttribute("EngineId")
    local gearboxId = car.Model:GetAttribute("GearboxId")
    local tireId = car.Model:GetAttribute("TireId")
    local state = driveState[car.Model]
    if not state then
        state = {gear = 1, rpm = 850, signature = "", spec = nil, lastTelemetry = 0}
        driveState[car.Model] = state
    end
    local signature = tostring(engineId) .. ":" .. tostring(gearboxId) .. ":" .. tostring(tireId)
    if state.signature ~= signature then
        state.spec = VehicleBuild.Resolve({
            engineId = if type(engineId) == "string" then engineId else "stock_i4",
            gearboxId = if type(gearboxId) == "string" then gearboxId else "street_5",
            tireId = if type(tireId) == "string" then tireId else "street",
        })
        if state.spec then
            state.gear = 1
            state.rpm = state.spec.idleRpm
        end
        state.signature = signature
    end
    local spec = state.spec
    if not spec then
        car.DriveForce.Force = Vector3.zero
        car.SuspensionForce.Force = Vector3.zero
        car.YawMotor.AngularVelocity = Vector3.zero
        return
    end
    local speedMps = longitudinal * 0.28
    state.rpm = Powertrain.EngineRpm(spec, state.gear, speedMps)
    if seat.Occupant and drive > 0 then
        state.gear = Powertrain.Shift(spec, state, drive)
    elseif not seat.Occupant then
        state.gear = 1
    end
    local baseline = VehicleMath.DriveAcceleration(
        drive, longitudinal, cfg.ForwardAcceleration, cfg.ReverseAcceleration,
        cfg.MaxForwardSpeed, cfg.MaxReverseSpeed
    )
    local powerMultiplier = math.clamp(
        Powertrain.WheelForce(spec, state.rpm, state.gear) / 7500, 0.35, 1.65
    )
    local acceleration = if drive > 0 then baseline * powerMultiplier else baseline
    local telemetryTime = os.clock()
    if telemetryTime - state.lastTelemetry >= 0.15 then
        car.Model:SetAttribute("EngineRPM", math.floor(state.rpm))
        car.Model:SetAttribute("Gear", state.gear)
        state.lastTelemetry = telemetryTime
    end

    local rayParams = raycastCache[car.Model]
    if not rayParams then
        rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {car.Model}
        rayParams.IgnoreWater = true
        raycastCache[car.Model] = rayParams
    end
    -- Four-point suspension approximation; contacts are computed server-side.
    -- Cosmetic welded wheels remain until real articulated suspension is built.
    local contacts = 0
    local friction = 0
    local spring = 0
    local rideLength = 4.5
    for _, offset in WHEEL_OFFSETS do
        local worldPoint = root.CFrame:PointToWorldSpace(offset)
        local hit = workspace:Raycast(worldPoint, Vector3.new(0, -rideLength, 0), rayParams)
        if hit and hit.Normal.Y > 0.6 then
            contacts += 1
            friction += VehicleMath.TractionFactor(hit.Material)
            local compression = 1 - hit.Distance / rideLength
            spring += VehicleMath.SpringAcceleration(compression, vel.Y, 380, 18)
        end
    end
    local grounded = contacts > 0
    -- The former 320 studs/s² cap could overwhelm gravity and launch the chassis.
    -- Use an acceleration envelope tied to workspace gravity instead.
    local suspensionAcceleration = math.clamp(spring / 4, 0, workspace.Gravity * 1.15)
    car.SuspensionForce.Force = Vector3.new(0, root.AssemblyMass * suspensionAcceleration, 0)
    if not grounded then
        car.DriveForce.Force = Vector3.zero
        car.YawMotor.AngularVelocity = Vector3.zero
        return
    end

    local mass = root.AssemblyMass
    local traction = (friction / contacts) * VehicleMath.ContactTraction(contacts)
    local grip = cfg.Grip * traction * (if tireId == "sport" then 1.2 elseif tireId == "worn" then 0.63 else 1)
    -- Dynamic lateral/longitudinal damping remains bound by the same acceleration envelope.
    car.DriveForce.Force = mass * (
        fwd * acceleration * traction
        - right * (lateral * grip)
        - planar * cfg.RollingDrag
    )

    car.YawMotor.AngularVelocity = Vector3.new(
        0,
        VehicleMath.SteeringAngularSpeed(steer, longitudinal, cfg.SteeringRate) * traction,
        0
    )
end

function VehicleService.SpawnForPlayer(player: Player, build: any, position: Vector3, heading: number?): Factory.Car?
    if not VehicleBuild.Resolve(build) then return nil end
    local folder = workspace:FindFirstChild("ActiveVehicles")
    if not folder then return nil end
    local success, created = pcall(function()
        -- Personal parking follows east-west streets (z=+/-200).
        return Factory.Create(folder, position, heading or math.pi / 2, player.UserId)
    end)
    if not success then
        warn("[StreetCity] Vehicle creation failed: " .. tostring(created))
        return nil
    end
    local car: Factory.Car = created
    Factory.ApplyCatalog(car, build.catalogId)
    car.Model:SetAttribute("VehicleHealth", 100)
    car.Model:SetAttribute("VehicleCondition", "operational")
    car.Model:SetAttribute("EngineId", build.engineId)
    car.Model:SetAttribute("GearboxId", build.gearboxId)
    car.Model:SetAttribute("TireId", build.tireId)
    table.insert(cars, car)
    driveState[car.Model] = { gear = 1, rpm = 850, signature = "", spec = nil, lastTelemetry = 0 }
    ownershipConnections[car.Model] = car.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        assignOwner(car)
    end)
    assignOwner(car)
    return car
end

function VehicleService.SpawnTrafficVehicle(catalogId: string, position: Vector3,
    heading: number, isPolice: boolean?): Factory.Car?
    local build = VehicleCatalog[catalogId]
    if not build then return nil end
    local folder = workspace:FindFirstChild("ActiveVehicles")
    if not folder then return nil end
    local safe, result = pcall(function()
        return Factory.Create(folder, position, heading, nil)
    end)
    if not safe then
        warn("[StreetCity] Ambient traffic spawn failed: " .. tostring(result))
        return nil
    end
    local car: Factory.Car = result
    Factory.ApplyCatalog(car, catalogId)
    car.Model:SetAttribute("EngineId", build.engineId)
    car.Model:SetAttribute("GearboxId", build.gearboxId)
    car.Model:SetAttribute("TireId", build.tireId)
    car.Model:SetAttribute("VehicleHealth", 100)
    car.Model:SetAttribute("VehicleCondition", "operational")
    car.Model:SetAttribute("TrafficNPC", true)
    car.Model:SetAttribute("IsPolice", isPolice == true)
    table.insert(cars, car)
    driveState[car.Model] = {gear = 1, rpm = 850, signature = "", spec = nil, lastTelemetry = 0}
    ownershipConnections[car.Model] = car.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        assignOwner(car)
    end)
    assignOwner(car)
    return car
end

function VehicleService.DespawnByModel(model: Model): boolean
    for _, car in cars do
        if car.Model == model then
            VehicleService.Despawn(car)
            return true
        end
    end
    return false
end

function VehicleService.SetTrafficControls(car: Factory.Car, throttle: number, steer: number)
    if car.Model.Parent == nil or car.Model:GetAttribute("TrafficNPC") ~= true
        or car.Seat.Occupant then return end
    inputState[car.Model] = {
        throttle = math.clamp(throttle, -1, 1),
        steer = math.clamp(steer, -1, 1),
        last = os.clock(),
    }
end

function VehicleService.Despawn(car: Factory.Car)
    local connection = ownershipConnections[car.Model]
    if connection then connection:Disconnect() end
    ownershipConnections[car.Model] = nil
    for i, entry in cars do
        if entry == car then table.remove(cars, i) break end
    end
    driveState[car.Model] = nil
    car.SuspensionForce.Force = Vector3.zero
    inputState[car.Model] = nil
    raycastCache[car.Model] = nil
    priorVelocity[car.Model] = nil
    priorImpactAt[car.Model] = nil
    car.Model:Destroy()
end

function VehicleService.Start()
    local folder = Instance.new("Folder")
    folder.Name = "ActiveVehicles"
    folder.Parent = workspace

    local remoteFolder = Instance.new("Folder")
    remoteFolder.Name = "StreetCityRemotes"
    remoteFolder.Parent = ReplicatedStorage

    local inputRemote = Instance.new("RemoteEvent")
    inputRemote.Name = "VehicleInput"
    inputRemote.Parent = remoteFolder
    inputRemote.OnServerEvent:Connect(function(player: Player, throttle: any, steer: any)
        if type(throttle) ~= "number" or type(steer) ~= "number" then return end
        if throttle ~= throttle or steer ~= steer
            or math.abs(throttle) > 1.01 or math.abs(steer) > 1.01 then return end
        local now = os.clock()
        if now - (inputThrottle[player.UserId] or 0) < 0.045 then return end
        inputThrottle[player.UserId] = now
        for _, car in cars do
            if isDriver(player, car) then
                inputState[car.Model] = {
                    throttle = math.clamp(throttle, -1, 1),
                    steer = math.clamp(steer, -1, 1),
                    last = now,
                }
                break
            end
        end
    end)

    local lightsRemote = Instance.new("RemoteEvent")
    lightsRemote.Name = "ToggleHeadlights"
    lightsRemote.Parent = remoteFolder

    -- A shared free test car exists only in an unpublished Studio session.
    -- Remote handlers and server heartbeat are initialized in EVERY environment.
    local car: Factory.Car? = nil
    if RunService:IsStudio() and game.GameId == 0 then
        local testCar = Factory.Create(folder, Vector3.new(0, 3.5, -30))
        testCar.Model:SetAttribute("EngineId", "stock_i4")
        testCar.Model:SetAttribute("GearboxId", "street_5")
        testCar.Model:SetAttribute("TireId", "street")
        table.insert(cars, testCar)
        driveState[testCar.Model] = {gear = 1, rpm = 850, signature = "", spec = nil, lastTelemetry = 0}
        ownershipConnections[testCar.Model] = testCar.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            assignOwner(testCar)
        end)
        assignOwner(testCar)
        car = testCar
    end

    lightsRemote.OnServerEvent:Connect(function(player: Player)
        local now = os.clock()
        if now - (cooldown[player.UserId] or 0) < 0.3 then
            return
        end
        cooldown[player.UserId] = now
        for _, vehicle in cars do
            if isDriver(player, vehicle) then
                local enabled = not vehicle.Headlights[1].Enabled
                for _, light in vehicle.Headlights do
                    light.Enabled = enabled
                end
                vehicle.Model:SetAttribute("HeadlightsOn", enabled)
                break
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        cooldown[player.UserId] = nil
        inputThrottle[player.UserId] = nil
    end)

    -- Limit server-side ground raycasts to ~30Hz instead of every Heartbeat.
    -- Actuators hold their most recent force between updates.
    local physicsAccumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        physicsAccumulator += dt
        if physicsAccumulator < 1 / 30 then return end
        physicsAccumulator = 0
        for _, vehicle in cars do
            if vehicle.Model.Parent then
                updateCar(vehicle)
            end
        end
    end)
    return car
end

return VehicleService
