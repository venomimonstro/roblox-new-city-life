--!strict
-- One authoritative, immutable course shared by game runtime and smoke tests.
local Course = {
    Start = Vector3.new(0, 1, 23),
    StartRadius = 26,
    CheckpointRadius = 16,
    MaxSpeed = 145, -- studs/s: generous arcade prototype threshold
    MaxDurationSeconds = 180,
    RewardCredits = 650,
    Points = table.freeze({
        Vector3.new(0, 1, 100),
        Vector3.new(200, 1, 100),
        Vector3.new(200, 1, -100),
        Vector3.new(0, 1, -100),
        Vector3.new(0, 1, -50),
        Vector3.new(0, 1, 23),
    }),
}
return table.freeze(Course)
