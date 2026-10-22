--!strict
-- Real Luau assertions, run from Studio bootstrap without paid API calls.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("LegalCareerCatalog"))
local Rules = require(Shared:WaitForChild("CareerRules"))
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Wallet = require(Shared:WaitForChild("GarageTransactions"))
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
    local fake = Schema.New(314)
    local operation = "career_test_once_0001"
    assert(Wallet.AwardCredits(fake, 410, operation), "First salary should be granted")
    assert(not Wallet.AwardCredits(fake, 410, operation),
        "Repeated UpdateAsync operation ID cannot pay salary twice")
    assert(fake.credits == 410 and Schema.Decode(fake) ~= nil,
        "Credit journal and persisted profile must stay consistent")
    assert(driving >= 6 and foot >= 8, "Both road and walking careers required")
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("StreetCityCareerStatus")
    assert(remote and remote:IsA("RemoteEvent"), "Missing authoritative mission HUD updates")
    print("[StreetCity] PASS: " .. tostring(#Catalog)
        .. " accessible careers, payout caps and route exploit checks")
end

return Tests
