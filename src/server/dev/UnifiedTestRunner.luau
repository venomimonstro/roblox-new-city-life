--!strict
-- One Studio test ledger for the entire game (not a fake-players simulation).
-- Its PASS does not certify device/multi-server/cloud tests; those are explicit BLOCKED.
local HttpService = game:GetService("HttpService")
local Tests = {}
local TEST_MODULES = {
    "SmokeTests", "CityTraversalTests", "CityInfillTests", "WorldTraversalTests",
    "TrafficSafetyTests", "TransitAndNpcTests", "VehicleDamageTests",
    "TransportPhysicsTests", "ScenarioTests", "SimulationTests", "CityLifeTests",
    "LegalCareerTests", "CareerWorldTests", "LifeEconomyTests",
    "DistrictEconomyTests", "SocialSystemsTests",
}
function Tests.Run()
    local report = {
        reportVersion = 1,
        suite = "StreetCity-Studio-Integration",
        createdAt = os.time(),
        modules = {} :: {any},
        passed = 0,
        failed = 0,
        notExecuted = 0,
        certification = "BLOCKED_EXTERNAL_ACCEPTANCE",
    }
    local dir = script.Parent
    for _, name in TEST_MODULES do
        local start = os.clock()
        local result = {
            name = name, passed = false, durationMs = 0,
            failure = "",
        }
        local module = dir:FindFirstChild(name)
        if not module or not module:IsA("ModuleScript") then
            result.failure = "Module missing or not a ModuleScript"
            report.notExecuted += 1
        else
            local success, err = pcall(function()
                local suite = require(module)
                assert(type(suite) == "table" and type(suite.Run) == "function",
                    "Test module missing Run method")
                suite.Run()
            end)
            if success then
                result.passed = true
                report.passed += 1
            else
                result.failure = tostring(err)
                report.failed += 1
            end
        end
        result.durationMs = math.floor((os.clock() - start) * 1000 + 0.5)
        table.insert(report.modules, result)
        if result.passed then
            print("[StreetCity IntegratedQA] PASS " .. name
                .. " (" .. tostring(result.durationMs) .. "ms)")
        else
            warn("[StreetCity IntegratedQA] FAIL " .. name
                .. ": " .. result.failure)
        end
    end
    -- Human-readable and JSON-line receipt from the SAME running Roblox server.
    -- The external Studio automation should capture its output, write the file,
    -- and join it with the git commit and multi-client staging measurements.
    print("[StreetCity IntegratedQA JSON] " .. HttpService:JSONEncode(report))
    assert(report.failed == 0 and report.notExecuted == 0
        and report.passed == #TEST_MODULES,
        "[StreetCity IntegratedQA] BLOCKED: one or more required Studio suites failed")
    print("[StreetCity IntegratedQA] PASS " .. tostring(report.passed)
        .. "/" .. tostring(#TEST_MODULES)
        .. " Studio suites. External certification remains BLOCKED.")
end
return table.freeze(Tests)
