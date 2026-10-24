--!strict
-- Comprehensive Studio integration runner: execute ALL suites even if one fails.
-- Emits one summary receipt, prevents a false "PASS" after only an early subset.
local HttpService = game:GetService("HttpService")
local Runner = {}

local SUITES = {
    "SmokeTests",
    "CityTraversalTests",
    "CityInfillTests",
    "WorldTraversalTests",
    "TrafficSafetyTests",
    "TransitAndNpcTests",
    "VehicleDamageTests",
    "TransportPhysicsTests",
    "ScenarioTests",
    "SimulationTests",
    "CityLifeTests",
    "LegalCareerTests",
    "CareerWorldTests",
    "LifeEconomyTests",
    "DistrictEconomyTests",
    "SocialSystemsTests",
}

function Runner.Run()
    local completed = 0
    local failures: {string} = {}
    local results = {}
    local started = os.clock()
    for _, name in SUITES do
        local at = os.clock()
        local module = script.Parent:FindFirstChild(name)
        local ok, err = xpcall(function()
            assert(module and module:IsA("ModuleScript"),
                "Missing test suite " .. name)
            local suite = require(module)
            assert(type(suite) == "table" and type(suite.Run) == "function",
                "Test module lacks Run(): " .. name)
            suite.Run()
        end, debug.traceback)
        if ok then
            completed += 1
            print("[City Acceptance] PASS " .. name)
        else
            table.insert(failures, name .. ": " .. tostring(err))
            warn("[City Acceptance] FAIL " .. name .. " - " .. tostring(err))
        end
        table.insert(results, {
            name = name, status = if ok then "PASS" else "FAIL",
            durationSeconds = math.floor((os.clock() - at) * 1000 + 0.5) / 1000,
        })
    end
    local passed = #failures == 0
    local receipt = {
        status = if passed then "PASS" else "FAIL",
        totalSuites = #SUITES,
        passedSuites = completed,
        failedSuites = #failures,
        durationSeconds = math.floor((os.clock() - started) * 1000 + 0.5) / 1000,
        results = results,
    }
    -- Receipt is human and machine-readable in the Studio server Output.
    local encoded = HttpService:JSONEncode(receipt)
    print("[City Acceptance] RECEIPT " .. encoded)
    game:GetService("ReplicatedStorage"):SetAttribute("StreetCityStudioSuiteReceipt", encoded)
    if not passed then
        error("[City Acceptance] " .. tostring(#failures)
            .. " integration suites failed:\n" .. table.concat(failures, "\n"))
    end
    print("[City Acceptance] ALL " .. tostring(completed)
        .. " Studio suites passed. Multiplayer/playability requires separate evidence.")
    return receipt
end

return table.freeze(Runner)
