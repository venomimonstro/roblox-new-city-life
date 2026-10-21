--!strict
-- Pure domain simulation. Runs only in Studio, with zero DataStore/network/Robux calls.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Dynamics = require(Shared:WaitForChild("DistrictDynamics"))
local Rules = require(Shared:WaitForChild("GarageTransactions"))
local Properties = require(Shared:WaitForChild("PropertyTransactions"))
local Scenario = {}

function Scenario.Run()
    local tests = 0
    local function check(value: any, explanation: string)
        assert(value, "[District Economy] " .. explanation)
        tests += 1
    end

    local player = Schema.New(26)
    check(Schema.Decode(player) ~= nil and player.schemaVersion == 4,
        "New V4 profile must deserialize")
    local legacyV3 = Schema.New(28)
    legacyV3.schemaVersion = 3
    legacyV3.realEstate = nil
    legacyV3.ownedProperties = nil
    legacyV3.communityBankCredits = nil
    legacyV3.allegiance = nil
    legacyV3.guards = nil
    legacyV3.henchmen = nil
    local upgraded = Schema.Decode(legacyV3)
    check(upgraded and upgraded.schemaVersion == 4
        and upgraded.communityBankCredits == 0
        and upgraded.allegiance == "independent",
        "V3 account migration must not lose money or personal starter")

    local oldV4 = Schema.New(28)
    oldV4.allegiance = nil
    oldV4.ownedProperties = nil
    oldV4.communityBankCredits = nil
    check(Schema.Decode(oldV4) ~= nil,
        "Older V4 without later optional modules must stay readable")

    local district = Dynamics.New("downtown")
    Dynamics.Recalculate(district)
    local originalSafety, originalPrice = district.safety, district.propertyIndex
    check(Dynamics.Apply(district, "crime", 4) and district.safety < originalSafety,
        "Crimes worsen district safety")
    check(district.propertyIndex < originalPrice, "Crime reduces housing index")
    check(Dynamics.Apply(district, "security", 5), "Guard interventions accepted")
    check(district.safety > originalSafety - 12, "Protection recovers safety")
    check(Dynamics.ResidentCount(district) >= 1 and Dynamics.ResidentCount(district) <= 5,
        "Citizen count bounded")

    for _ = 1, 8 do check(Dynamics.Apply(district, "crime", 5),
        "Repeated crime accepted with bounded parameters") end
    check(not Dynamics.BankOperating(district),
        "Unsafe district can force local branch to suspend service")
    check(Dynamics.Apply(district, "civic", 5), "Civic activity accepted")
    check(not Dynamics.Apply(district, "unknown", 2), "Unknown district event rejected")
    check(not Dynamics.Apply(district, "crime", 1000), "Huge untrusted impact rejected")

    player.credits = 20000
    check(Properties.Buy(player, "downtown_flat", 3600, "property_buy_001"),
        "Real estate must support more than the small 2000-credits service cap")
    check(player.credits == 16400 and player.ownedProperties.downtown_flat ~= nil,
        "One-time deed debit and ownership")
    check(not Properties.Buy(player, "downtown_flat", 3600, "property_buy_001"),
        "Duplicate deed purchase rejected")
    check(Properties.SetRental(player, "downtown_flat", true, 1800000000),
        "NPC tenancy can be enabled")
    check(not Properties.CollectRent(player, "downtown_flat", 1800000100, "rent_early_001"),
        "Rent cannot be claimed before lease duration")
    check(Properties.CollectRent(player, "downtown_flat", 1800000310, "rent_ok_00001"),
        "Elapsed rent can be paid")
    check(not Properties.CollectRent(player, "downtown_flat", 1800000310, "rent_ok_00001"),
        "Repeated rent may not mint credits")

    check(Rules.SetAllegiance(player, "law", 1800000000),
        "Change alignment with server timestamp")
    check(not Rules.SetAllegiance(player, "outlaw", 1800000001),
        "Alignment changes rate limited")
    check(Rules.HireFollower(player, "guard", "hire_guard_0001"),
        "Paid lawful companion contract persists")
    check(player.guards == 1, "Hired guard count stored")
    check(not Rules.HireFollower(player, "henchman", "hire_wrong_0001"),
        "Lawkeepers cannot recruit outlaw associates")
    check(Rules.LoseFollower(player, "guard") and player.guards == 0,
        "Companion removal supports arrest or loss")
    check(Schema.Decode(player) ~= nil, "Fully mutated V4 account validates")

    print("[StreetCity] PASS: " .. tostring(tests)
        .. " district economy, profile migration, bank, property and faction assertions")
end

return Scenario
