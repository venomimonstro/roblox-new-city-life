--!strict
return table.freeze({
    World = {
        Seed = 24021,
        RoadSpacing = 100,
        RoadWidth = 25,
        BlockCount = 4,
    },
    Vehicle = {
        MaxForwardSpeed = 95, -- studs/second: provisional arcade controller
        MaxReverseSpeed = 24,
        ForwardAcceleration = 23, -- studs/second^2
        ReverseAcceleration = 11,
        Grip = 7.5,
        RollingDrag = 0.85,
        SteeringRate = 1.65, -- radians/second
    },
})
