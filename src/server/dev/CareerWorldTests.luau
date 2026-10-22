--!strict
-- World-space acceptance for every paid shift. This uses actual Studio raycasts,
-- not only source string matches, and catches inaccessible workplaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("LegalCareerCatalog"))
local Tests = {}

local function checkPoint(position: Vector3, label: string, drivable: boolean)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local exclude = {}
    for _, name in {"ActiveVehicles"} do
        local folder = workspace:FindFirstChild(name)
        if folder then table.insert(exclude, folder) end
    end
    params.FilterDescendantsInstances = exclude
    -- Avoid reading a hovering sign as a drivable collision surface.
    local result = workspace:Raycast(position + Vector3.new(0, 12, 0),
        Vector3.new(0, -65, 0), params)
    assert(result ~= nil, "[Career World] Missing floor: " .. label)
    assert(result.Instance.CanCollide and result.Normal.Y > 0.75,
        "[Career World] Unsafe sloped or decorative floor: " .. label)
    assert(math.abs(result.Position.Y - position.Y) <= 12,
        "[Career World] Workplace is above or below accessible ground: " .. label)
    -- Vehicle destinations are road-side drop-offs; the avatar may finish on
    -- adjacent terrain. Do not require a specific material at the kiosk.
    if drivable then
        assert(result.Normal.Y > 0.88, "[Career World] Driving mission cliff: " .. label)
    end
end

function Tests.Run()
    local count = 0
    for _, job in Catalog do
        checkPoint(job.start, job.id .. " starting shift", false)
        count += 1
        for index, stop in job.stops do
            checkPoint(stop, job.id .. " stop " .. tostring(index),
                job.mode == "vehicle")
            count += 1
        end
    end
    local jobs = workspace:WaitForChild("StreetCityPrototypeWorld")
        :WaitForChild("CityJobs")
    for _, name in {"JobStart_taxi", "JobFinish_taxi",
        "JobStart_firefighter", "JobFinish_firefighter",
        "JobStart_police", "JobFinish_police",
        "JobStart_cleaner", "JobFinish_cleaner",
        "JobStart_office", "JobFinish_office",
        "Fish_Cast", "Fish_Catch", "Fish_Sell"} do
        local stand = jobs:FindFirstChild(name)
        assert(stand and stand:IsA("BasePart"),
            "[Career World] Missing first-generation work location: " .. name)
        checkPoint(stand.Position, name, false)
        count += 1
    end
    print("[Career World] PASS: " .. tostring(count)
        .. " job starts and destinations have real walkable collision support")
end

return Tests
