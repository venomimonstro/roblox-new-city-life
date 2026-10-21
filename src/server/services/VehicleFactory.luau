--!strict
local VehicleFactory = {}

export type Car = {
    Model: Model,
    Chassis: Part,
    Seat: VehicleSeat,
    DriveForce: VectorForce,
    YawMotor: AngularVelocity,
    Headlights: { SpotLight },
}

local function weldTo(root: BasePart, child: BasePart)
    child.Anchored = false
    child.Massless = true
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = child
    weld.Parent = child
end

local function geometry(
    model: Model,
    root: Part,
    name: string,
    size: Vector3,
    offset: CFrame,
    color: Color3
): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = root.CFrame * offset
    p.Material = Enum.Material.SmoothPlastic
    p.Color = color
    p.CanCollide = false
    p.Parent = model
    weldTo(root, p)
    return p
end

function VehicleFactory.Create(parent: Instance, position: Vector3): Car
    local model = Instance.new("Model")
    model.Name = "PrototypeCoupe"
    model:SetAttribute("StreetCityVehicle", true)

    local chassis = Instance.new("Part")
    chassis.Name = "Chassis"
    chassis.Size = Vector3.new(5.6, 2.5, 10.5)
    chassis.CFrame = CFrame.new(0, 0, 0)
    chassis.Color = Color3.fromRGB(28, 39, 48)
    chassis.Material = Enum.Material.Metal
    chassis.Anchored = false
    chassis.CanCollide = true
    chassis.Parent = model
    model.PrimaryPart = chassis

    local seat = Instance.new("VehicleSeat")
    seat.Name = "DriverSeat"
    seat.Size = Vector3.new(2.4, 0.55, 2)
    seat.CFrame = chassis.CFrame * CFrame.new(0, 1.5, 0.3)
    seat.HeadsUpDisplay = false
    seat.Parent = model
    weldTo(chassis, seat)

    geometry(model, chassis, "Hood", Vector3.new(5.4, 0.55, 3),
        CFrame.new(0, 1.2, -3.3), Color3.fromRGB(205, 53, 63))
    geometry(model, chassis, "Rear", Vector3.new(5.4, 0.65, 2.5),
        CFrame.new(0, 1.2, 3.7), Color3.fromRGB(205, 53, 63))
    geometry(model, chassis, "Windshield", Vector3.new(5, 1.6, 0.18),
        CFrame.new(0, 2.3, -1.55) * CFrame.Angles(math.rad(-19), 0, 0),
        Color3.fromRGB(52, 105, 140))

    for _, x in { -3.1, 3.1 } do
        for _, z in { -3.5, 3.5 } do
            local wheel = geometry(model, chassis, "Wheel",
                Vector3.new(2.45, 1.05, 2.45),
                CFrame.new(x, -0.02, z) * CFrame.Angles(0, 0, math.rad(90)),
                Color3.fromRGB(22, 23, 27))
            wheel.Shape = Enum.PartType.Cylinder
        end
    end

    local lights: { SpotLight } = {}
    for _, x in { -2.05, 2.05 } do
        local lamp = geometry(model, chassis, "Headlamp",
            Vector3.new(0.85, 0.35, 0.16), CFrame.new(x, 0.7, -5.3),
            Color3.fromRGB(234, 227, 187))
        lamp.Material = Enum.Material.Neon
        local spot = Instance.new("SpotLight")
        spot.Face = Enum.NormalId.Front
        spot.Angle = 58
        spot.Range = 44
        spot.Brightness = 2
        spot.Enabled = false
        spot.Parent = lamp
        table.insert(lights, spot)
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Drive"
    prompt.ObjectText = "Test car"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = 11
    prompt.RequiresLineOfSight = false
    prompt.Parent = seat
    prompt.Triggered:Connect(function(player: Player)
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 or seat.Occupant then
            return
        end
        if player:DistanceFromCharacter(seat.Position) > 12 then
            return
        end
        seat:Sit(humanoid)
    end)

    local attachment = Instance.new("Attachment")
    attachment.Name = "DriveAttachment"
    attachment.Parent = chassis
    local driveForce = Instance.new("VectorForce")
    driveForce.Name = "DriveForce"
    driveForce.ApplyAtCenterOfMass = true
    driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
    driveForce.Attachment0 = attachment
    driveForce.Force = Vector3.zero
    driveForce.Parent = chassis

    local yaw = Instance.new("AngularVelocity")
    yaw.Name = "YawMotor"
    yaw.Attachment0 = attachment
    yaw.RelativeTo = Enum.ActuatorRelativeTo.World
    yaw.MaxTorque = 1000000
    yaw.AngularVelocity = Vector3.zero
    yaw.Parent = chassis

    model:PivotTo(CFrame.new(position))
    model.Parent = parent
    return {
        Model = model,
        Chassis = chassis,
        Seat = seat,
        DriveForce = driveForce,
        YawMotor = yaw,
        Headlights = lights,
    }
end

return VehicleFactory
