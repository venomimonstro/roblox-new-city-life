--!strict
-- Real Luau assertions, run from Studio bootstrap without paid API calls.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("LegalCareerCatalog"))
local Rules = require(Shared:WaitForChild("CareerRules"))
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Wallet = require(Shared:WaitForChild("GarageTransactions"))
local ShiftRegistry = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("WorkShiftRegistry"))
local Tests = {}

function Tests.Run()
    assert(#Catalog >= 16, "A meaningful selection of legal jobs is required")
    local seen = {}
    local driving, foot = 0, 0
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
        :FindFirstChild("LegalCareers")
    assert(root and root:IsA("Folder"), "Public careers were not installed")
    for _, job in Catalog do
        assert(type(job.id) == "string" and job.id:match("^[a-z_]+$")
            and not seen[job.id], "Job ID must be unique and safe")
        seen[job.id] = true
        assert(type(job.title) == "string" and #job.title >= 3)
        assert(type(job.reward) == "number" and job.reward >= 80
            and job.reward <= 900 and job.reward % 1 == 0,
            "Reward cap must match Wallet.AwardCredits")
        assert(job.mode == "vehicle" or job.mode == "foot")
        if job.mode == "vehicle" then driving += 1 else foot += 1 end
        assert(typeof(job.start) == "Vector3" and #job.stops == 2,
            "Each shift must have a two-stop ordered route")
        local startPad = root:FindFirstChild("CareerStart_" .. job.id)
        assert(startPad and startPad:IsA("BasePart")
            and startPad:FindFirstChild("CareerPrompt"),
            "Unreachable or missing job onboarding")
        assert(not startPad.CanCollide and not startPad.CanQuery,
            "Career starts must not obstruct roads")
        local from = job.start
        for _, stop in job.stops do
            assert(typeof(stop) == "Vector3", "Stop position malformed")
            local legLength = (Vector3.new(from.X, 0, from.Z)
                - Vector3.new(stop.X, 0, stop.Z)).Magnitude
            assert(legLength >= 90 and legLength <= 600,
                "Job checkpoints must be reachable and require travel")
            local minTime = Rules.MinimumTravelSeconds(from, stop, job.mode)
            local minDistance = Rules.RequiredDistance(from, stop)
            assert(not Rules.CanFinishLeg(from, stop, stop, minTime - 1,
                minDistance, job.mode, true), "Early waypoint exploit")
            assert(not Rules.CanFinishLeg(from, stop, stop, minTime + 1,
                minDistance - 1, job.mode, true), "Standing at waypoint exploit")
            assert(not Rules.CanFinishLeg(from, stop, stop, minTime + 1,
                minDistance, job.mode, false), "Vehicle/foot mismatch exploit")
            assert(not Rules.CanFinishLeg(from, stop, stop + Vector3.new(0, 30, 0),
                minTime + 1, minDistance, job.mode, true),
                "Teleporting above waypoint exploit")
            assert(Rules.CanFinishLeg(from, stop, stop, minTime + 1,
                minDistance + 2, job.mode, true),
                "Completed legitimate waypoint rejected")
            from = stop
        end
    end
    assert(Rules.MaximumMovementForSample(0.3, "foot") > 7,
        "Normal sprint distance must not trigger false positive")
    assert(Rules.MaximumMovementForSample(0.3, "foot") < 20,
        "Foot teleport microsteps must not earn career travel")
    assert(Rules.MaximumMovementForSample(0.3, "vehicle") > 35,
        "Ordinary city driving must be permitted")
    assert(Rules.MaximumMovementForSample(0, "foot") == 0
        and Rules.MaximumMovementForSample(2, "unknown") == 0,
        "Invalid or duplicate sample times fail closed")
    -- Multi-platform: delivering to a doorstep after leaving the owned car.
    local goal = Vector3.new(200, 2, 100)
    local carNear = Vector3.new(188, 4, 102)
    local walker = Vector3.new(195, 3, 104)
    assert(Rules.CanDeliverAfterParking(goal, carNear, 100, 114, walker),
        "Legitimate player should finish after parking the owned car")
    assert(not Rules.CanDeliverAfterParking(goal, carNear, 100, 122, walker),
        "Stale car parking location cannot complete mission")
    assert(not Rules.CanDeliverAfterParking(goal, Vector3.new(70, 4, 100),
        100, 105, walker), "Parked too far away is invalid")
    assert(not Rules.CanDeliverAfterParking(goal, carNear, 100, 105,
        Vector3.new(195, 50, 104)), "Teleporting above a waypoint must fail")
    assert(not Rules.CanDeliverAfterParking(goal, nil, 100, 105, walker),
        "Walking without owned car cannot complete driving career")
    local fake = Schema.New(314)
    local operation = "career_test_once_0001"
    assert(Wallet.AwardCredits(fake, 410, operation), "First salary should be granted")
    assert(not Wallet.AwardCredits(fake, 410, operation),
        "Repeated UpdateAsync operation ID cannot pay salary twice")
    assert(fake.credits == 410 and Schema.Decode(fake) ~= nil,
        "Credit journal and persisted profile must stay consistent")
    local fakePlayerId = -920014
    assert(ShiftRegistry.Claim(fakePlayerId, "career_parcel"),
        "First shift must reserve a worker")
    assert(not ShiftRegistry.Claim(fakePlayerId, "legacy_taxi"),
        "Second career provider cannot overlap")
    assert(not ShiftRegistry.Release(fakePlayerId, "legacy_taxi"),
        "Unrelated service cannot release another shift")
    assert(ShiftRegistry.Active(fakePlayerId) == "career_parcel",
        "Ownership must survive forged unlock")
    assert(ShiftRegistry.Release(fakePlayerId, "career_parcel"),
        "Worker may finish or cancel shift")
    assert(ShiftRegistry.Claim(fakePlayerId, "legacy_taxi"),
        "A player can accept another job after release")
    assert(ShiftRegistry.Release(fakePlayerId, "legacy_taxi"),
        "Shared shift lock cleaned for subsequent tests")
    assert(driving >= 6 and foot >= 8, "Both road and walking careers required")
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("StreetCityCareerStatus")
    assert(remote and remote:IsA("RemoteEvent"), "Missing authoritative mission HUD updates")
    print("[StreetCity] PASS: " .. tostring(#Catalog)
        .. " accessible careers, payout caps and route exploit checks")
end

return Tests
