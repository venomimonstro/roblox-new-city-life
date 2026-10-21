--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local VehicleMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleMath"))
local Factory = require(script.Parent:WaitForChild("VehicleFactory"))
local Powertrain = require(ReplicatedStorage.Shared:WaitForChild("Powertrain"))
local Catalog = require(ReplicatedStorage.Shared:WaitForChild("PartsCatalog"))

local VehicleService = {}
local cars: { Factory.Car } = {}
local cooldown: { [number]: number } = {}
local ownershipConnections: { RBXScriptConnection } = {}
local driveState: { [Model]: { gear: number, rpm: number } } = {}

local function isDriver(player: Player, car: Factory.Car): boolean
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and car.Seat.Occupant == humanoid
end

local function assignOwner(car: Factory.Car)
    local occupant = car.Seat.Occupant
    local owner = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
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
    car.Model:SetAttribute("DriverUserId", if owner then owner.UserId else 0)
end

local function updateCar(car: Factory.Car)
    local root = car.Chassis
    local seat = car.Seat
    local cfg = Config.Vehicle
    if not root:IsDescendantOf(workspace) then
        return
    end
    local vel = root.AssemblyLinearVelocity
    local fwd = root.CFrame.LookVector
    local right = root.CFrame.RightVector
    local longitudinal = vel:Dot(fwd)
    local lateral = vel:Dot(right)
    local planar = Vector3.new(vel.X, 0, vel.Z)

    local drive = if seat.Occupant then seat.ThrottleFloat else 0
    local steer = if seat.Occupant then seat.SteerFloat else 0
    -- Early simulation integration: gear ratios affect drive acceleration. The chassis
    -- is still arcade physics; wheel/suspension constraints are a later milestone.
    local spec = Catalog.CreateSpec("stock_i4", "street_5", "street")
    assert(spec ~= nil)
    local state = driveState[car.Model]
    if not state then
        state = { gear = 1, rpm = spec.idleRpm }
        driveState[car.Model] = state
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
    car.Model:SetAttribute("EngineRPM", math.floor(state.rpm))
    car.Model:SetAttribute("Gear", state.gear)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { car.Model }
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -5.5, 0), rayParams)
    local grounded = hit ~= nil and hit.Normal.Y > 0.6
    if not grounded then
        car.DriveForce.Force = Vector3.zero
        car.YawMotor.AngularVelocity = Vector3.zero
        return
    end

    local mass = root.AssemblyMass
    local traction = VehicleMath.TractionFactor(hit.Material)
    local grip = cfg.Grip * traction
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

function VehicleService.Start()
    local folder = Instance.new("Folder")
    folder.Name = "ActiveVehicles"
    folder.Parent = workspace

    local remoteFolder = Instance.new("Folder")
    remoteFolder.Name = "StreetCityRemotes"
    remoteFolder.Parent = ReplicatedStorage

    local lightsRemote = Instance.new("RemoteEvent")
    lightsRemote.Name = "ToggleHeadlights"
    lightsRemote.Parent = remoteFolder

    local car = Factory.Create(folder, Vector3.new(0, 3.5, -30))
    table.insert(cars, car)
    driveState[car.Model] = { gear = 1, rpm = 850 }
    table.insert(ownershipConnections, car.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        assignOwner(car)
    end))
    assignOwner(car)

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
    end)

    RunService.Heartbeat:Connect(function(_dt)
        for _, vehicle in cars do
            if vehicle.Model.Parent then
                updateCar(vehicle)
            end
        end
    end)
end

return VehicleService
