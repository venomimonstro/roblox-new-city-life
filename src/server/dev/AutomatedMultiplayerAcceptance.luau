--!strict
-- StudioTestService orchestration for *real* connected player models.
-- Only runs if automated multiplayer test args explicitly enable it.
-- No DataStore writes, Robux products or developer-only account mutation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local Services = script.Parent.Parent:WaitForChild("services")
local Profile = require(Services:WaitForChild("ProfileService"))
local Housing = require(Services:WaitForChild("HousingService"))
local Garage = require(Services:WaitForChild("PersonalGarage"))
local Test = {}
local ARG = "STREET_CITY_RELEASE_AUTOMATION_V1"
local watchers: {[number]: boolean} = {}
local clientReceipts: {[number]: boolean} = {}

local function assertPlayer(player: Player): (any, any)
    assert(Profile.IsLoaded(player), "Player profile not loaded: " .. player.UserId)
    local record = Profile.Read(player)
    assert(record and record.selectedVehicleId and record.garage[record.selectedVehicleId],
        "Missing selected owned vehicle in persisted profile")
    local plot = Housing.GetGarageSpawn(player)
    assert(plot and plot.slot ~= nil and plot.position, "Missing private home")
    local car = Garage.GetActive(player)
    assert(car and car.Model.Parent and car.Seat and car.Chassis,
        "Physical owned car missing")
    assert(car.Model:GetAttribute("OwnerUserId") == player.UserId, "Incorrect car owner")
    assert(car.Model:GetAttribute("OwnedVehicleId") == record.selectedVehicleId,
        "Physical vehicle does not match selected saved car")
    assert((car.Chassis.Position - plot.position).Magnitude < 55,
        "Owned car did not start in the home neighborhood")
    local char = player.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    assert(human and human.Health > 0 and root and root:IsA("BasePart"),
        "Missing live playable avatar")
    local home = Housing.GetHomePosition(player)
    assert(home and (root.Position - home).Magnitude < 65,
        "Player did not spawn by their home")
    return record, plot
end

local function waitUntil(predicate: () -> boolean, seconds: number): boolean
    local began = os.clock()
    while os.clock() - began < seconds do
        local success, result = pcall(predicate)
        if success and result then return true end
        task.wait(0.5)
    end
    return false
end

local function runTwoPlayers()
    local checks = {}
    local function result(name: string, passed: boolean)
        table.insert(checks, {name=name, status=if passed then "PASS" else "FAIL"})
        assert(passed, "Multiplayer user journey failed: " .. name)
    end

    result("two_real_clients_connected",
        waitUntil(function() return #Players:GetPlayers() == 2 end, 60))
    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return a.UserId < b.UserId end)
    local first, second = players[1], players[2]
    result("both_profiles_homes_and_cars_ready", waitUntil(function()
        local x, okX = pcall(assertPlayer, first)
        local y, okY = pcall(assertPlayer, second)
        return x and okX and y and okY
    end, 65))
    local before, plotA = assertPlayer(first)
    local other, plotB = assertPlayer(second)
    result("private_plot_slots_unique", plotA.slot ~= plotB.slot)
    result("private_vehicle_ownership_unique",
        Garage.GetActive(first).Model ~= Garage.GetActive(second).Model
        and Garage.GetActive(first).Model:GetAttribute("OwnerUserId") ~= second.UserId)
    result("two_client_HUD_receipts", waitUntil(function()
        return clientReceipts[first.UserId] and clientReceipts[second.UserId]
    end, 45))

    -- Death is tested against the actual Humanoid.Died event and personal
    -- garage lifecycle, never by manually calling a pure settlement rule.
    local priorDeaths = before.deathCount or 0
    local savedHomeCash = before.homeCredits or 0
    local avatar = first.Character
    local humanoid = avatar and avatar:FindFirstChildOfClass("Humanoid")
    assert(humanoid and humanoid.Health > 0, "Avatar unexpectedly unavailable")
    humanoid.Health = 0
    result("actual_death_and_free_home_respawn", waitUntil(function()
        if first.Character == avatar then return false end
        local h = first.Character and first.Character:FindFirstChildOfClass("Humanoid")
        return h ~= nil and h.Health > 0
    end, 45))
    result("medical_accounting_after_death", waitUntil(function()
        local record = Profile.Read(first)
        return record and record.deathCount == priorDeaths + 1
            and (record.homeCredits or 0) == savedHomeCash
    end, 45))
    result("owned_vehicle_replaced_after_death", waitUntil(function()
        local ok = pcall(assertPlayer, first)
        return ok
    end, 45))
    result("other_account_untouched", (function()
        local now = Profile.Read(second)
        return now ~= nil and now.deathCount == other.deathCount
            and now.credits == other.credits
    end)())
    return {status="PASS", mode=ARG, players=2, checks=checks}
end

function Test.Start()
    if not RunService:IsStudio() then return end
    local safeArgs, args = pcall(function() return StudioTestService:GetTestArgs() end)
    if not safeArgs or args ~= ARG then return end
    assert(game:GetAttribute("StreetCityAllowStudioDataStore") ~= true,
        "Automated life-cycle tests refuse persistent staging or real accounts")

    local receiptEvent = Instance.new("RemoteEvent")
    receiptEvent.Name = "StreetCityClientTestReceipt"
    receiptEvent.Parent = ReplicatedStorage
    receiptEvent.OnServerEvent:Connect(function(player, version: any, success: any)
        if version ~= ARG or success ~= true then return end
        if player.Parent == Players then clientReceipts[player.UserId] = true end
    end)
    Players.PlayerRemoving:Connect(function(player)
        clientReceipts[player.UserId] = nil
        watchers[player.UserId] = nil
    end)

    task.spawn(function()
        local passed, report = xpcall(function()
            local runnerReceipt = ReplicatedStorage:GetAttribute("StreetCityStudioSuiteReceipt")
            assert(type(runnerReceipt) == "string" and runnerReceipt:find('"status":"PASS"', 1, true),
                "Studio unit/integration suites did not produce a PASS receipt")
            return runTwoPlayers()
        end, debug.traceback)
        local result = if passed then report else {status="FAIL", mode=ARG,
            error=tostring(report)}
        local encoded = HttpService:JSONEncode(result)
        print("[StreetCity Automated Multiplayer] RECEIPT " .. encoded)
        -- The Studio command-line driver receives this result directly.
        StudioTestService:EndTest(encoded)
    end)
end
return table.freeze(Test)
