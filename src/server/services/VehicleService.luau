--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local VehicleMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleMath"))
local Factory = require(script.Parent:WaitForChild("VehicleFactory"))

local VehicleService = {}
local cars: { Factory.Car } = {}
local cooldown: { [number]: number } = {}

local function isDriver(player: Player, car: Factory.Car): boolean
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and car.Seat.Occupant == humanoid
end

local function updateCar(car: Factory.Car)
    local root = car.Chassis
    local seat = car.Seat
    local cfg = Config.Vehicle
    local vel = root.AssemblyLinearVelocity
    local fwd = root.CFrame.LookVector
    local right = root.CFrame.RightVector
    local longitudinal = vel:Dot(fwd)
    local lateral = vel:Dot(right)
    local planar = Vector3.new(vel.X, 0, vel.Z)

    local acceleration = VehicleMath.DriveAcceleration(
        if seat.Occupant then seat.ThrottleFloat else 0,
        longitudinal,
        cfg.ForwardAcceleration,
        cfg.ReverseAcceleration,
        cfg.MaxForwardSpeed,
        cfg.MaxReverseSpeed
    )
    local groundParams = RaycastParams.new()
    groundParams.FilterType = Enum.RaycastFilterType.Exclude
    groundParams.FilterDescendantsInstances = { car.Model }
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), groundParams)
    local grounded = hit ~= nil and hit.Normal.Y > 0.5
    if not grounded then
        car.DriveForce.Force = Vector3.zero
        car.YawMotor.AngularVelocity = Vector3.zero
        return
    end

    local mass = root.AssemblyMass
    car.DriveForce.Force = mass * (
        fwd * acceleration
        - right * (lateral * cfg.Grip)
        - planar * cfg.RollingDrag
    )
    local yawSpeed = VehicleMath.SteeringAngularSpeed(
        if seat.Occupant then seat.SteerFloat else 0,
        longitudinal,
        cfg.SteeringRate
    )
    car.YawMotor.AngularVelocity = Vector3.new(0, yawSpeed, 0)
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
